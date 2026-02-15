This is a Docker image for hosting your own 5eTools instance. It is based on the Apache `httpd` Alpine image and follows the official [5eTools installation guidance](https://wiki.tercept.net/en/5eTools/InstallGuide). The container builds the 5eTools project at runtime using npm, ensuring you always get a properly built version with the latest updates. This image is built from [this GitHub repository](https://github.com/Sakujakira/5etools-docker).

This project is based on the original repository: https://github.com/Jafner/5etools-docker.

## Comparison with Original Image

This fork provides several improvements over the original implementation:

### Image Size & Security
| Metric | This Image (Alpine 3.23) | Original (Debian 12) | Improvement |
|--------|--------------------------|----------------------|-------------|
| **Image Size** | 152 MB | 279 MB | **1.8x smaller** |
| **Installed Packages** | 62 | 154 | **2.5x fewer** |
| **Total CVEs** | 2 | 3525 | **substantially fewer** |
| **Critical CVEs** | 0 | 14 | **100% elimination** |
| **High CVEs** | 0 | 912 | **100% elimination** |
| **Medium CVEs** | 1 | 2554 | **substantially fewer** |
| **Low CVEs** | 1 | 45 | **substantially fewer** |

*Measured on February 15, 2026 using local `docker build`, `docker image inspect`, `apk info`, and Trivy (`--ignore-unfixed`). Results vary over time as base images and vulnerability DBs change.*

### Key Differences
- **Base Image**: Alpine Linux 3.23 (latest) vs Debian 12 (Bookworm)
- **Runtime Build**: Builds project at startup following official 5eTools installation flow (npm ci, build:sw:prod, optional SEO)
- **Zero Critical/High CVEs**: All critical and high-severity vulnerabilities eliminated ✅
- **Smaller Attack Surface**: 2.5x fewer packages means significantly fewer potential vulnerabilities
- **Active Maintenance**: Always uses latest Alpine version with most recent security patches
- **Automated Security**: Dependabot + Trivy scanning on every build
- **Security Hardening**: Removes git metadata (.git, .github) and build artifacts after installation
- **Smart Updates**: Compares local `package.json` version with remote release tag and rebuilds only when different
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
- Multi-architecture builds (linux/amd64, linux/arm64) on pushes/PRs to `main` except ignored paths (`.github/**`, `docker-compose.yml`, `*.md`, `.gitignore`, `.dockerignore`)
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
- Minimal package installation (git, jq, su-exec, npm, curl)
- **Build artifact cleanup**: Removes .git, .github, node_modules after build to reduce attack surface
- **Git cache isolation**: Image repository .git stored in separate cache directory
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

```bash
curl -o docker-compose.yml https://raw.githubusercontent.com/Sakujakira/5etools-docker/refs/heads/main/docker-compose.yml
docker-compose up -d && docker logs -f 5etools-docker
```

**First startup takes 5-10 minutes** as the container:
1. Clones the 5eTools source repository from GitHub
2. Installs npm dependencies
3. Builds the project (service worker, optional SEO optimization)
4. Cleans up build artifacts

Subsequent restarts are much faster as the container detects the existing version and only rebuilds if an update is available.

The site will be accessible at `localhost:8080` once the build completes. Monitor progress with `docker logs -f 5etools-docker`.

Files persist in Docker-managed named volumes. Use `docker-compose down -v` to remove volumes and start fresh.

## Volume Mapping

### Default: Named Volumes (Recommended)
By default, the container uses **Docker-managed named volumes** for data persistence:
- `htdocs`: Built 5eTools files
- `logs`: Apache logs
- `git-cache`: Git repository cache for faster image updates

This is the recommended approach as it:
- Persists data between container restarts
- Works seamlessly across different host systems
- Keeps volumes separate from your file system

To start fresh, remove volumes with: `docker-compose down -v`

### Alternative: Host Directory Mapping
If you need direct file access (e.g., for adding homebrew), use host-mounted volumes:

```yaml
volumes:
  - ~/5etools-docker/htdocs:/usr/local/apache2/htdocs
  - ~/5etools-docker/logs:/usr/local/apache2/logs
  - ~/5etools-docker/git-cache:/root/.cache/git
```

**Note**: With host volumes, you can access built files directly, but you'll need to handle file permissions correctly (use PUID/PGID environment variables).

### External Docker Volumes
To use pre-created Docker volumes:

```bash
docker volume create 5etools-htdocs
docker volume create 5etools-logs
docker volume create 5etools-git-cache
```

Then in `docker-compose.yml`:
```yaml
volumes:
  htdocs:
    external: true
    name: 5etools-htdocs
  logs:
    external: true
    name: 5etools-logs
  git-cache:
    external: true
    name: 5etools-git-cache
```

## Environment Variables
The image uses environment variables for configuration. By default, it automatically downloads and builds the latest 5eTools version from GitHub. All variables are optional with sensible defaults.

### IMG (default: FALSE)
Controls whether to download image files alongside the main content.

```yaml
environment:
  - IMG=TRUE   # Download images (~2GB, takes longer)
  - IMG=FALSE  # Skip images (default, faster startup)
```

- `TRUE`: Clones image repository from https://github.com/5etools-mirror-3/5etools-img
- `FALSE`: Main content only, no artwork/maps (faster, smaller)

The container uses a git cache to speed up subsequent image updates.

### OFFLINE_MODE (default: FALSE)
Skip GitHub updates and use existing built files.

```yaml
environment:
  - OFFLINE_MODE=TRUE
```

Useful for air-gapped environments. Requires pre-built files in the volume. Container exits if no local version exists.

In `OFFLINE_MODE=TRUE`, the container does not call the GitHub API and does not attempt repository updates.

### SEO_OPTION (default: FALSE)
Build SEO-optimized version of the site.

```yaml
environment:
  - SEO_OPTION=TRUE
```

Runs `npm run build:seo` after the standard build. See [5eTools Install Guide](https://wiki.tercept.net/en/5eTools/InstallGuide) for details.

### NPM_AUDIT_FORCE_FIX (default: FALSE)
Force npm to fix vulnerabilities that may introduce breaking changes.

```yaml
environment:
  - NPM_AUDIT_FORCE_FIX=TRUE
```

**⚠️ Use with caution**: May introduce breaking changes. By default, the container runs `npm audit fix` without `--force` flag for safer updates.

### PUID and PGID (default: 1000)
Control file ownership and Apache worker process user/group.

```yaml
environment:
  - PUID=1001  # User ID
  - PGID=1001  # Group ID
```

The container dynamically creates a user/group with specified IDs and:
- Sets ownership of all built files to PUID:PGID
- Configures Apache worker processes to run as PUID:PGID
- Ensures proper file permissions for host-mounted volumes

**Why this matters**: Match your host user's UID/GID to access files without permission issues when using host-mounted volumes.

## Integrating a reverse proxy
Supporting integration of a reverse proxy is beyond the scope of this guide. 
However, any instructions which work for the base `httpd` (Apache) image, should also work for this, as it is minimally different.

# Auto-loading homebrew
To use auto-loading homebrew, you will need to use a **host directory mapping** (not named volumes). Update your `docker-compose.yml` to use host-mounted volumes as described in the Volume Mapping section above.

1. Start the container and wait for the build to complete. Monitor progress with `docker logs -f 5etools-docker` (first build takes 5-10 minutes).
2. Once running, assuming you are using the mapping `~/5etools-docker/htdocs:/usr/local/apache2/htdocs`, place your homebrew JSON files into the `~/5etools-docker/htdocs/homebrew/` folder.
3. Add the filenames to the `~/5etools-docker/htdocs/homebrew/index.json` file.
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
        "This file contains an index for other homebrew files, which should be placed in the same directory.",
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

**Note**: The `IS_DEPLOYED` flag in `js/utils.js` is automatically set to the deployed version number during the build process, enabling homebrew support. You don't need to manually edit this file.

Note the commas after each entry except the last in each array.
See the [5eTools Install Guide](https://wiki.tercept.net/en/5eTools/InstallGuide) for more information.

---

## Reproducible Metrics Note
To reproduce the comparison table on your machine, run:

```bash
# Build current image from this repository
docker build -t 5etools-doc-review:local .

# Current image metrics
docker image inspect 5etools-doc-review:local --format '{{.Size}}'
docker run --rm 5etools-doc-review:local sh -lc "apk info | wc -l"
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest \
  image --ignore-unfixed --severity CRITICAL,HIGH,MEDIUM,LOW --format table 5etools-doc-review:local

# Original image metrics
docker pull jafner/5etools-docker:latest
docker image inspect jafner/5etools-docker:latest --format '{{.Size}}'
docker run --rm jafner/5etools-docker:latest sh -lc "dpkg-query -W -f='${binary:Package}\n' | wc -l"
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest \
  image --ignore-unfixed --severity CRITICAL,HIGH,MEDIUM,LOW --format table jafner/5etools-docker:latest
```

Use one scanner/toolchain consistently for both images. CVE counts can change daily as vulnerability databases and base image tags are updated.

## AI-Assisted Development Disclaimer

This project was developed with assistance from Claude (Anthropic's AI assistant) for:
- Documentation writing and formatting
- Code reviews and security analysis
- Identifying potential issues and suggesting improvements

**However, all architectural decisions, implementation choices, and code changes were made by the repository maintainer.** The AI served as a development tool for analysis and documentation, not as the primary author of the codebase.

The core improvements (Alpine migration, security enhancements, git operation fixes, and privilege separation) were designed and implemented by human developers. 
