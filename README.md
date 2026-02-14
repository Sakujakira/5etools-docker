This is a simple image for hosting your own 5eTools instance. It is based on the Apache `httpd` Alpine image and uses components of the auto-updater script from the [5eTools wiki](https://wiki.tercept.net/en/5eTools/InstallGuide). This image is built from [this GitHub repository](https://github.com/Sakujakira/5etools-docker).

This project is based on the original repository: https://github.com/Jafner/5etools-docker.

## Comparison with Original Image

This fork provides several improvements over the original implementation:

### Image Size & Security
| Metric | This Image (Alpine 3.23) | Original (Debian 12) | Improvement |
|--------|--------------------------|----------------------|-------------|
| **Image Size** | 76 MB | 279 MB | **3.7× smaller** |
| **Packages** | 66 | 224 | **3.4× fewer** |
| **Total CVEs** | 10 | 173 | **94% fewer vulnerabilities** |
| **Critical CVEs** | 0 | 7 | **100% elimination** ✅ |
| **High CVEs** | 0 | 34 | **100% elimination** ✅ |
| **Medium CVEs** | 8 | 39 | **79% fewer** |
| **Low CVEs** | 2 | 95 | **98% fewer** |

*CVE data from Docker Scout as of February 2026*

### Key Differences
- **Base Image**: Alpine Linux 3.23 (latest) vs Debian 12 (Bookworm)
- **Zero Critical/High CVEs**: All critical and high-severity vulnerabilities eliminated ✅
- **Smaller Attack Surface**: 3.4× fewer packages means significantly fewer potential vulnerabilities
- **Active Maintenance**: Always uses latest Alpine version with most recent security patches
- **Automated Security**: Dependabot + Trivy scanning on every build
- **Improved Git Operations**: Robust handling of repository updates with `git reset --hard` + `git pull`
- **Enhanced Security Model**: See Security section below

### Why Alpine?
Alpine Linux is purpose-built for containers with minimal bloat. The smaller footprint means:
- Faster image pulls and container startup
- Reduced disk space usage
- Fewer packages to patch and maintain
- Smaller attack surface for security vulnerabilities

### CI/CD & Automated Security
This project implements comprehensive automated security monitoring:

**Continuous Integration/Deployment:**
- Multi-architecture builds (linux/amd64, linux/arm64) on every commit
- Automated builds pushed to both GitHub Container Registry and Docker Hub
- Docker build caching for faster iterations

**Automated Vulnerability Scanning:**
- **Trivy scanner** runs on every push to main branch
- Scans for OS and library vulnerabilities (Critical, High, Medium severity)
- Results automatically uploaded to GitHub Security tab as SARIF reports
- Build artifacts are scanned using image digest for accuracy
- Secondary summary report highlights Critical/High vulnerabilities

**Dependency Management:**
- **Dependabot** monitors base images and GitHub Actions daily/weekly
- Automatic pull requests for security updates
- Keeps dependencies current with minimal manual intervention

**Security Visibility:**
View real-time security scan results in your repository's **Security → Code scanning** tab. All vulnerability findings are tracked and can trigger alerts for new CVEs.

## Security

This implementation follows Docker security best practices:

### Non-Root Execution
- **Apache worker processes run as non-root** (PUID/PGID specified user)
- Apache master process runs as root only for initial setup (standard Apache practice)
- All web content files owned by non-root user (PUID:PGID)
- Privilege separation via Apache's native User/Group directives

### File Permissions
- Downloaded files are owned by the user specified via `PUID`/`PGID` environment variables
- Apache logs directory properly permissioned for non-root access
- Git operations complete before ownership transfer to ensure consistent permissions

### Container Security
- Minimal package installation (git, jq, su-exec only)
- `.dockerignore` prevents sensitive files in build context
- Healthcheck monitors container status
- Idempotent startup script handles container restarts gracefully

### Comparison with Original
The original implementation runs Apache entirely as root, while this fork properly segregates privileges:
- **Original**: All Apache processes run as root
- **This fork**: Master as root (required), workers as PUID:PGID (least privilege)

This follows the principle of least privilege and reduces the impact of potential Apache vulnerabilities.

# Usage
Below we talk about how to install and configure the container. 

## Default Configuration
You can quick-start this image by running:

```
mkdir -p ~/5etools-docker/htdocs && cd ~/5etools-docker
curl -o docker-compose.yml https://raw.githubusercontent.com/Sakujakira/5etools-docker/refs/heads/main/docker-compose.yml
docker-compose up -d && docker logs -f 5etools-docker
```

Then give the container a few minutes to come online (it takes a while to pull the Github repository) and it will be accessible at `localhost:8080`.
When you stop the container, it will automatically delete itself. The downloaded files will remain in the `~/5etools-docker/htdocs` directory, so you can always start the container back up by running `docker-compose up -d`.

## Volume Mapping
By default, I assume you want to keep downloaded files, even if the container dies. And you want the downloaded files to be located at `~/5etools-docker/htdocs`.  

If you want the files to be located somewhere else on your system, change the left side of the volume mapping. For example, if I wanted to keep my files at `~/data/docker/5etools`, the volume mapping would be:

```
    volumes:
      - ~/data/docker/5etools:/usr/local/apache2/htdocs
```

Alternatively, you can have Docker or Compose manage your volume. (This makes adding homebrew practically impossible.)  

Use a Compose-managed volume with:
```
...
    volumes:
      - 5etools-docker:/usr/local/apache2/htdocs
...
volumes:
  5etools-docker:
```

Or have the Docker engine manage the volume (as opposed to Compose). First, create the volume with `docker volume create 5etools-docker`, then add the following to your `docker-compose.yml`:
```
...
    volumes:
      - 5etools-docker:/usr/local/apache2/htdocs
...
volumes:
  5etools-docker:
    external: true
```

## Environment Variables
The image uses environment variables to figure out how you want it to run. 
By default, I assume you want to automatically download the latest files from the Github mirror. Use the environment variables in the `docker-compose.yml` file to configure things.

### IMG (defaults to FALSE)
Required unless OFFLINE_MODE=TRUE.
Expects one of "TRUE", "FALSE" Where:  
  > "TRUE" pulls from https://github.com/5etools-mirror-3/5etools-src and adds https://github.com/5etools-mirror-3/5etools-img as a submodule for image files.
  > "FALSE" pulls from https://github.com/5etools-mirror-3/5etools-src without image files.  

The get.5e.tools source has been down (redirecting to 5e.tools) during development. This method is not tested.  

### OFFLINE_MODE
Optional. Expects "TRUE" to enable. 
Setting this to true tells the server to run from the local files if available, or exits if there is no local version. 

### PUID and PGID (defaults to 1000)
These environment variables control the user and group ownership of files in the container.

```yaml
environment:
  - PUID=1001  # User ID
  - PGID=1001  # Group ID
```

The container dynamically creates a user/group with the specified IDs at startup and:
- Sets ownership of all downloaded files to PUID:PGID
- Configures Apache worker processes to run as PUID:PGID
- Ensures proper file permissions for your host system

**Why this matters**: If your host user is UID 1001, set `PUID=1001` so you can easily edit files outside the container without permission issues.

## Integrating a reverse proxy
Supporting integration of a reverse proxy is beyond the scope of this guide. 
However, any instructions which work for the base `httpd` (Apache) image, should also work for this, as it is minimally different.

# Auto-loading homebrew
To use auto-loading homebrew, you will need to use a host directory mapping as described above. 

1. Online the container and wait for the container to finish starting. You can monitor its progress with `docker logs -f 5etools-docker`.
2. Assuming you are using the mapping `~/5etools-docker/htdocs:/usr/local/apache2/htdocs` place your homebrew json files into the `~/5etools-docker/htdocs/homebrew/` folder, then add their filenames to the `~/5etools-docker/htdocs/homebrew/index.json` file.
For example, if your homebrew folder contains:
```
index.json
'Jafner; JafnerBrew Campaigns.json'
'Jafner; JafnerBrew Collection.json'
'Jafner; Legendary Tomes of Knowledge.json'
'KibblesTasty; Artificer (Revised).json'
```
Then your `index.json` should look like:
```json
{
    "readme": [
        "NOTE: This feature is designed for use in user-hosted copies of the site, and not for integrating \"official\" 5etools content.",
        "The \"production\" version of the site (i.e., not the development ZIP) has this feature disabled. You can re-enable it by replacing `IS_DEPLOYED = \"X.Y.Z\";` in the file `js/utils.js`, with `IS_DEPLOYED = undefined;`",
        "This file contains as an index for other homebrew files, which should be placed in the same directory.",
        "For example, add \"My Homebrew.json\" to the \"toImport\" array below, and have a valid JSON homebrew file in this (\"homebrew/\") directory."
    ],
    "toImport": [
        "Jafner; JafnerBrew Collection.json",
        "Jafner; JafnerBrew Campaigns.json",
        "Jafner; Legendary Tomes of Knowledge.json",
        "KibblesTasty; Artificer (Revised).json"
    ]
}
```

Note the commas after each entry except the last in each array.
See the [wiki page](https://wiki.5e.tools/index.php/5eTools_Install_Guide) for more information.

---

## AI-Assisted Development Disclaimer

This project was developed with assistance from Claude (Anthropic's AI assistant) for:
- Documentation writing and formatting
- Code reviews and security analysis
- Identifying potential issues and suggesting improvements

**However, all architectural decisions, implementation choices, and code changes were made by the repository maintainer.** The AI served as a development tool for analysis and documentation, not as the primary author of the codebase.

The core improvements (Alpine migration, security enhancements, git operation fixes, and privilege separation) were designed and implemented by human developers. 