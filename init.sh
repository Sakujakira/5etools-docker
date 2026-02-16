#!/bin/sh
set -e # Exit on error
set -o xtrace    # Debugging: Befehle anzeigen

PUID=${PUID:-1000}
PGID=${PGID:-1000}
DL_LINK=${DL_LINK:-https://github.com/5etools-mirror-3/5etools-src.git}
IMG_LINK=${IMG_LINK:-https://github.com/5etools-mirror-3/5etools-img.git}
VERSION=""
OFFLINE_MODE=${OFFLINE_MODE:-FALSE}
IMG=${IMG:-FALSE}
SEO_OPTION=${SEO_OPTION:-FALSE}
NPM_AUDIT_FORCE_FIX=${NPM_AUDIT_FORCE_FIX:-FALSE}

. /lib/common.sh # Import common functions
init_log # Initialize logging

# Function to get the latest version number from the GitHub repository using the GitHub API
# We dont want to have .git artifacts in htdocs, so we can't use git commands to get the version number. 
# Instead, we will use the GitHub API to get the latest release tag.
# TODO: This function currently only works with Github, we should expand the functionality to gitlab and gitea.
get_remote_version() {
    OWNER=$(echo "$DL_LINK" | sed -E 's#^https://github.com/(.*)/(.*)\.git$#\1#')
    REPO=$(echo "$DL_LINK" | sed -E 's#^https://github.com/(.*)/(.*)\.git$#\2#')
    VERSION=$(curl -s "https://api.github.com/repos/$OWNER/$REPO/releases/latest" | jq -r .tag_name)
}

# Function to print startup information
# This includes the PUID/PGID being used, the links for the source code and images, and the versions of Node.js and NPM.
# Purpose is to provide useful information for debugging and to confirm that the container is using the expected configuration.
print_startup_info() {
    log "Starting 5etools Docker Container" "INFO"
    if [ "$PUID" -eq 1000 ] && [ "$PGID" -eq 1000 ]; then
        log "No PUID or PGID provided, using defaults (1000:1000)" "INFO"
    else
        log "Custom PUID or PGID provided, using $PUID:$PGID" "INFO"
    fi

    log "These Links will be used:" "INFO"
    log "DL_LINK: $DL_LINK" "INFO"
    log "IMG_LINK: $IMG_LINK" "INFO"

    log "Node.js: $(node -v)" "INFO"
    log "NPM: $(npm -v)" "INFO"
}

# Since there are multiple places where we need to configure git, we will use a function to do it. This ensures that all git operations use the same configuration and reduces code duplication.
init_git() {
    git config --global core.compression 0 # Disable compression to speed up git operations, since we are throwing away the .git directory after pulling the latest version, we don't need the compression and it can actually slow down the process.
    git config --global http.postBuffer 524288000 # Set postBuffer to 500MB to prevent issues with large repositories
    git config --global user.email "autodeploy@localhost"
    git config --global user.name "AutoDeploy"
    git config --global pull.rebase false # Squelch nag message
    git config --global --add safe.directory '/usr/local/apache2/htdocs' # Disable directory ownership checking, required for mounted volumes
    git clone --depth=1 "$DL_LINK" . # clone the repo with no files and no object history
}

start_httpd_workers_unprevileged() {
    log "$(printf "Starting version %s" "$VERSION")" "INFO"
    log "$(printf "Configuring Apache to run as user %s:%s\n" "$PUID" "$PGID")" "INFO"
    # Configure Apache to run worker processes as the specified user/group
    sed -i "s/^User .*/User #$PUID/" /usr/local/apache2/conf/httpd.conf
    sed -i "s/^Group .*/Group #$PGID/" /usr/local/apache2/conf/httpd.conf
    httpd-foreground
}

build_project() {
    log "Building project with npm...\n" "INFO"
    npm ci 
    if [ "$NPM_AUDIT_FORCE_FIX" = "TRUE" ]; then
        log "Running npm audit fix with --force...\n" "WARN"
        npm audit fix --force
    else
        log "Running npm audit fix...\n" "INFO"
        npm audit fix || true # We ignore the exit code of npm audit fix, since it can return a non-zero exit code if there are vulnerabilities that cannot be fixed, but we still want to continue with the build process.
    fi
    npm run build:sw:prod
    if [ "$SEO_OPTION" = "TRUE" ]; then
        npm run build:seo
    fi
    cleanup_working_build_directory
}

cleanup_working_build_directory() {
    # Remove any build artifacts that are not needed for the server to run
    rm -rf /usr/local/apache2/htdocs/node_modules \
        /usr/local/apache2/htdocs/.git \
        /usr/local/apache2/htdocs/.github \
        /usr/local/apache2/htdocs/.gitignore \
        /usr/local/apache2/htdocs/.gitattributes \
        /usr/local/apache2/htdocs/.dockerignore \
        /usr/local/apache2/htdocs/.editorconfig \
        /usr/local/apache2/htdocs/Dockerfile \
        /usr/local/apache2/htdocs/CONTRIBUTING.md \
        /usr/local/apache2/htdocs/favicon_source_files.zip \
        /usr/local/apache2/htdocs/ISSUE_TEMPLATE.md \
        /usr/local/apache2/htdocs/img/.node-version \
        /usr/local/apache2/htdocs/img/NOTES_AUTOMATION.md \
        /usr/local/apache2/htdocs/img/NOTES_FAVICON.md \
        /usr/local/apache2/htdocs/img/SVGs.zip \
        /usr/local/apache2/htdocs/LICENSE.md

        sed -i '/globalThis\.IS_DEPLOYED = undefined;/s/undefined/"'"${VERSION}"'"/' "/usr/local/apache2/htdocs/js/utils.js" 
}

cleanup_working_img_directory() {
    # Since the img Repo is very large, we will move the .git directory to a different location to save space and reduce the attack surface. 
    # We will also remove any other files that are not needed for the server to run, such as README.md or LICENSE files.
    if [ -d /usr/local/apache2/htdocs/img/.git ]; then
        mv /usr/local/apache2/htdocs/img/.git /root/.cache/git/.git
    fi
    rm -rf /usr/local/apache2/htdocs/img/LICENSE \
        /usr/local/apache2/htdocs/img/.github \
        /usr/local/apache2/htdocs/img/.gitignore \
        /usr/local/apache2/htdocs/img/.gitattributes \
        /usr/local/apache2/htdocs/img/.dockerignore \
        /usr/local/apache2/htdocs/img/.editorconfig \
        /usr/local/apache2/htdocs/img/Dockerfile
}

###################################################################################################
#################################### !Main script starts here! ####################################             
###################################################################################################

print_startup_info

# If User and group don't exist, create them. If they do exist, ignore the error and continue.
addgroup -g "$PGID" appgroup 2>/dev/null || true
adduser -D -u "$PUID" appuser -G appgroup  2>/dev/null || true

# If the user doesn't want to update from a source, 
# check for local version.
# If local version is found, print version and start server.
# If no local version is found, print error message and exit.
# TODO: Outsource this to a separate function for better readability and maintainability.
if [ "$OFFLINE_MODE" = "TRUE" ]; then 
  log "Offline mode is enabled. Will try to launch from local files. Checking for local version...\n"
  if [ -f /usr/local/apache2/htdocs/package.json ]; then
    VERSION=$(jq -r .version /usr/local/apache2/htdocs/package.json) # Get version from package.json
    log "Starting version $VERSION\n" "INFO"
    log "Configuring Apache to run as user $PUID:$PGID\n" "INFO"
    start_httpd_workers_unprevileged
  else
    log "No local version detected. Exiting.\n" "ERROR"
    exit 1
  fi
fi

get_remote_version

# Move to the working directory for working with files.
cd /usr/local/apache2/htdocs || exit

log "Checking directory permissions for /usr/local/apache2/htdocs\n" "INFO"
ls -ld /usr/local/apache2/htdocs

# We will check package.json Version instead of using git commands to check the version, since we don't want to have .git artifacts in the htdocs directory.
# Also after building with npm we will have several new files in the directory, which would make it difficult to use git commands to check the version.
# Since this is small Repo throwing everything out and redownloading it is not a big deal, but we want to avoid unnecessary downloads if the version is already up to date.
# Therefore we will check the version in package.json and only pull from git if the version is different from the remote version. If the version is the same, we will skip pulling from git and just start the server.
log "Using GitHub mirror at %s\n" "$DL_LINK" "INFO"
if [ ! -f "/usr/local/apache2/htdocs/package.json" ]; then
    log "No existing package.json found, assuming empty directory\n" "INFO"
    log "Cleaning directory before git clone\n" "INFO"
    rm -rf /usr/local/apache2/htdocs/* /usr/local/apache2/htdocs/.[!.]* /usr/local/apache2/htdocs/..?* # Remove all files/dirs to ensure clean clone
    log "No existing git repository, creating one\n" "INFO"
    init_git
    build_project
elif [ -f "/usr/local/apache2/htdocs/package.json" ] && [ "$(jq -r .version /usr/local/apache2/htdocs/package.json)" = "${VERSION#v}" ]; then
    log "Local version matches remote version ($VERSION), skipping git pull\n" "INFO"
elif [ -f "/usr/local/apache2/htdocs/package.json" ] && [ "$(jq -r .version /usr/local/apache2/htdocs/package.json)" != "${VERSION#v}" ]; then
    log "Local version does not match remote version, resetting local files\n" "WARN"
    rm -rf /usr/local/apache2/htdocs/* /usr/local/apache2/htdocs/.[!.]* /usr/local/apache2/htdocs/..?* # Remove all files in htdocs, including dotfiles such as .git
    init_git
    build_project
else
    log "Unexpected state, exiting\n" "ERROR"
    log "Probably means that package.json is malformed.\n" "ERROR"
    log "Resetting the local files...\n" "WARN"
    rm -rf /usr/local/apache2/htdocs/* /usr/local/apache2/htdocs/.[!.]* /usr/local/apache2/htdocs/..?* # Remove all files in htdocs, including dotfiles such as .git
    init_git
    build_project
fi

# Now we should have a package.json file in place, we can check for the version and print it. 
# If the version is not found, we will print "unknown (no package.json)".
if [ -f /usr/local/apache2/htdocs/package.json ]; then
    VERSION=$(jq -r .version /usr/local/apache2/htdocs/package.json) # Get version from package.json
    log "Detected version %s\n" "$VERSION" "INFO"
    log "5eTools src should now be up to date and ready to use.\n" "INFO"
else 
    VERSION="unknown (no package.json)"
    log "No package.json found, cannot determine version. Exiting.\n" "ERROR"
    exit 1
fi

# Since the img Project doesnt have package.json, we can't check for the version.
# Instead, we will pull the Project information from the API and save it to a file. 
# If the file already exists, we will check if the version matches the remote version. 
# If it doesn't match, we will pull the new version. If it does match, we will skip pulling the new version.
# Since this Repo is very large, we will use git but with --depth=1 to only pull the latest version without the history.
# This should reduce the amount of data we need to download and speed up the process.
# From a security perspective, we should move everything that could contain sensitive metadata to a different directory
# and only temporarily retrieve it to the working directory when the container starts.  
# Since we are throwing away the .git directory from 5etools-src we cant use git submodules to manage the img Repo, but
#  we can still use git to pull the latest version of the img Repo and then move away the .git directory. 
if [ "$IMG" = "TRUE" ]; then # if user wants images
    if [ -d /root/.cache/git/.git ]; then
        log "Existing git cache for img repository found, using it to speed up the pull\n" "INFO"
        mkdir -p /usr/local/apache2/htdocs/img
        mv /root/.cache/git/.git /usr/local/apache2/htdocs/img/.git
        git -C /usr/local/apache2/htdocs/img fetch --depth=1 origin main && git -C /usr/local/apache2/htdocs/img reset --hard origin/main
        cleanup_working_img_directory
    else
        log "No existing git cache for img repository, creating one\n" "INFO"
        log "This will take a while, since the img repository is very large.\n" "INFO"
        mkdir -p /root/.cache/git
        log "Cloning img repository (%s) into /usr/local/apache2/htdocs/img ...\n" "$IMG_LINK" "INFO"
        git clone --depth=1 --progress "$IMG_LINK" /usr/local/apache2/htdocs/img
        log "Img repository clone complete. Current HEAD:\n" "INFO"
        git -C /usr/local/apache2/htdocs/img rev-parse --short HEAD || true
        cleanup_working_img_directory
    fi  
fi

# Since git ran as root, we need to change ownership of the htdocs and logs directories to the non-root user.
# This must happen AFTER all git operations are complete.
log "Setting ownership of files to %s:%s\n" "$PUID" "$PGID" "INFO"
chown -R "$PUID":"$PGID" /usr/local/apache2/htdocs
chown -R "$PUID":"$PGID" /usr/local/apache2/logs

ls -la /usr/local/apache2/htdocs

start_httpd_workers_unprevileged
