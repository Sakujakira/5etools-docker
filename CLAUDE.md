# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Docker containerization of 5etools (D&D 5th edition tools) based on Alpine Linux with Apache httpd. The container automatically clones/updates the 5etools repository from GitHub and serves it via Apache.

## Architecture

**Container Startup Flow:**
1. `init.sh` is the entry point (CMD in Dockerfile), runs as root
2. Creates dynamic user/group (appuser/appgroup) based on PUID/PGID environment variables
3. Either runs in OFFLINE_MODE (uses existing files) or clones/builds from GitHub:
   - In online mode, fetches latest version info from GitHub API (using curl)
   - Checks local package.json version against remote version
   - Clones source repository if needed (shallow clone --depth=1)
   - Builds project at runtime using `npm ci`, `npm audit fix`, and `npm run build:sw:prod`
   - Optionally builds SEO-optimized version if SEO_OPTION=TRUE
   - Removes build artifacts and git metadata (.git, .github, node_modules, etc.) for security
4. Optionally clones images repository if IMG=TRUE:
   - Uses git cache at `/root/.cache/git` to speed up subsequent pulls
   - Moves .git directory to cache after clone/update to reduce attack surface
5. Completes all git operations as root (required for permissions)
6. Sets ownership of htdocs and logs directories to PUID:PGID (after all operations)
7. Modifies Apache httpd.conf to set User/Group directives to PUID/PGID
8. Starts `httpd-foreground` as root - Apache master runs as root, workers drop to PUID:PGID

**Key Paths:**
- `/usr/local/apache2/htdocs/` - Web root, mapped to named volume for persistence
- `/usr/local/apache2/logs/` - Apache logs, mapped to named volume
- `/root/.cache/git/` - Git cache directory for img repository (speeds up updates)
- `/init.sh` - Container entry point script

**Base Image:** `httpd:2-alpine` (Latest Alpine-based Apache - currently Alpine 3.23)

**Source Repositories:**
- Main content: `https://github.com/5etools-mirror-3/5etools-src.git`
- Images (optional): `https://github.com/5etools-mirror-3/5etools-img.git`
- Note: Project uses mirror-3 repositories (updated from mirror-2)

## Common Commands

### Local Development & Testing

```bash
# Quick start with default configuration
docker-compose up -d && docker logs -f 5etools-docker

# Stop and remove container (files persist in named volumes)
docker-compose down

# Stop and remove container including volumes (clean slate)
docker-compose down -v

# Build image locally
docker build -t 5etools-docker .

# Build with custom PUID/PGID
docker build --build-arg PUID=1001 --build-arg PGID=1001 -t 5etools-docker .

# Test with images enabled
docker run -d -p 8080:80 -e IMG=TRUE 5etools-docker

# Test offline mode (requires pre-populated volume)
docker run -d -p 8080:80 -e OFFLINE_MODE=TRUE -v 5etools-htdocs:/usr/local/apache2/htdocs 5etools-docker

# Test with SEO build
docker run -d -p 8080:80 -e SEO_OPTION=TRUE 5etools-docker

# Test with forced npm audit fix
docker run -d -p 8080:80 -e NPM_AUDIT_FORCE_FIX=TRUE 5etools-docker

# Monitor container startup (useful for debugging - shows npm build process)
docker logs -f 5etools-docker
```

### Testing & Verification

```bash
# Verify Apache configuration syntax
docker run --rm <image> httpd -t
# Should output: "Syntax OK"

# Check server-status configuration formatting
docker run --rm <image> grep -A 5 "server-status" /usr/local/apache2/conf/httpd.conf
# Should show properly formatted Location block with real newlines

# Test container with custom PUID/PGID (first run takes longer due to npm build)
docker run -d --name test -p 8080:80 -e PUID=1001 -e PGID=1001 <image>

# Verify file ownership (should show UID:GID matching PUID:PGID)
docker exec test ls -ln /usr/local/apache2/htdocs | head -10

# Verify Apache worker processes run as non-root
docker exec test ps aux | grep httpd
# Master: root, Workers: appuser (UID matching PUID)

# Check HTTP response
curl -s http://localhost:8080 | head -20
# Should return valid 5etools HTML

# Verify healthcheck
docker inspect test --format='{{.State.Health.Status}}'
# Should show: healthy

# Cleanup
docker stop test && docker rm test
```

### CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/ci_cd.yml`) automatically:
- Builds multi-arch images (linux/amd64, linux/arm64) using QEMU and buildx
- Pushes to GHCR (`ghcr.io/<repo>`) and Docker Hub (`docker.io/<username>/5etools-docker`)
- Triggers on push to main branch (excluding changes to .github/**, docker-compose.yml, *.md, .gitignore, .dockerignore)
- Can be manually triggered via workflow_dispatch
- **Automated Security Scanning:** Trivy scans every build using image digest from Docker Hub
- **SARIF Upload:** Vulnerability results automatically uploaded to GitHub Security tab
- **Build Cache:** Uses GitHub Actions cache for faster multi-arch builds

**Trivy Vulnerability Scanner:**
1. **Primary Scan:** Scans pushed image using digest (`@sha256:...`) from build output
   - Scans for OS and library vulnerabilities
   - Reports Critical, High, and Medium severity CVEs
   - Uses `ignore-unfixed: true` to focus on actionable vulnerabilities
   - Uploads SARIF results to GitHub Security tab
   - Exit code 0 (doesn't fail build, only reports)

2. **Summary Scan:** Generates human-readable table of Critical/High CVEs
   - Scans `:latest` tag for quick summary
   - Exit code 1 if critical/high vulnerabilities found
   - Uses `continue-on-error: true` to avoid blocking workflow

**Dependabot Configuration:**
- Monitors Docker base image updates (daily checks)
- Monitors GitHub Actions version updates (weekly checks)
- Automatically creates PRs for dependency updates
- See `.github/dependabot.yml` for configuration

**Required GitHub Secrets:**
- `DOCKERHUB_USERNAME` - Docker Hub username
- `DOCKERHUB_TOKEN` - Docker Hub access token (used for Trivy authentication)
- `GITHUB_TOKEN` - Automatically provided by GitHub Actions

## Environment Variables

- `PUID` / `PGID` (default: 1000) - User/group ID for file ownership
- `DL_LINK` (default: https://github.com/5etools-mirror-3/5etools-src.git) - Source repository
- `IMG_LINK` (default: https://github.com/5etools-mirror-3/5etools-img.git) - Image repository
- `IMG` (default: FALSE) - Whether to pull image files from GitHub (no longer uses git submodule)
- `OFFLINE_MODE` (default: FALSE) - Skip GitHub API/repository updates, use existing files
- `SEO_OPTION` (default: FALSE) - Build SEO-optimized version using `npm run build:seo`
- `NPM_AUDIT_FORCE_FIX` (default: FALSE) - Run `npm audit fix --force` (caution: may introduce breaking changes)

## Critical Implementation Details

**init.sh script:**
- Uses `set -e` to exit on any error
- Uses `set -o xtrace` for debugging (shows executed commands in logs)
- **Structured with helper functions:**
  - `get_remote_version()` - Fetches latest version from GitHub API using curl
  - `print_startup_info()` - Displays startup information (PUID/PGID, links, Node/npm versions)
  - `init_git()` - Initializes git configuration (safe.directory, user, shallow clone)
  - `build_project()` - Runs npm build process (ci, audit fix, build:sw:prod, optional SEO build)
  - `cleanup_working_build_directory()` - Removes build artifacts and git metadata for security
  - `cleanup_working_img_directory()` - Moves img .git to cache and removes unnecessary files
  - `start_httpd_workers_unprevileged()` - Configures and starts Apache
- Creates user/group dynamically (idempotent with `2>/dev/null || true` to handle container restarts)
- **Version detection:** Uses GitHub API (not git commands) to check remote version
- **Smart updates:** Compares local package.json version with remote, only rebuilds if different
- Uses shallow clone (`--depth=1`) for faster downloads
- **Runtime build process:**
  - `npm ci` - Clean install dependencies
  - `npm audit fix` - Fixes vulnerabilities (optionally with --force)
  - `npm run build:sw:prod` - Builds service worker
  - `npm run build:seo` - Optional SEO build
- **Security cleanup:** Removes .git, .github, node_modules, and other artifacts after build
- **Image handling (IMG=TRUE):**
  - No longer uses git submodules
  - Clones to `/usr/local/apache2/htdocs/img`
  - Moves .git to `/root/.cache/git` for faster subsequent updates
  - Reuses cached .git on container restarts
- **Critical:** Sets ownership of htdocs and logs directories to PUID:PGID AFTER all operations complete
- Modifies Apache httpd.conf User/Group directives via `sed` to match PUID/PGID
- Starts `httpd-foreground` (Apache master as root, workers as PUID:PGID - Apache's native privilege dropping)
- Always runs `httpd-foreground` to keep container alive

**Dockerfile:**
- Cleans htdocs directory with safe pattern: `rm -rf * .[!.]* ..?*` (excludes . and ..)
- Uses `COPY --chmod=755` for init.sh to ensure executability
- **Dependencies:** git, jq, su-exec, npm, curl (Alpine packages)
  - npm: Required for runtime build process
  - curl: Required for GitHub API version checks
  - git/jq: Required for git operations and JSON parsing
  - su-exec: Not currently used but available for future use
- Uses `printf` (not `echo`) to add `/server-status` endpoint to httpd.conf with proper newlines
- `/server-status` endpoint exposed to all IPs (security consideration: information disclosure risk)
- Healthcheck endpoint: `http://localhost/` (checks main page returns 200)
- Container runs as root, but Apache worker processes run as PUID:PGID (Apache's native User/Group directives)

## Implementation Verification Checklist

**All critical items have been implemented and tested:**

1. ✅ **User/group creation idempotency** - Error suppression handles container restarts:
   ```sh
   addgroup -g "$PGID" appgroup 2>/dev/null || true
   adduser -D -u "$PUID" appuser -G appgroup 2>/dev/null || true
   ```

2. ✅ **File ownership timing** - `chown` executes AFTER all operations (critical for proper ownership):
   ```sh
   # All git operations, npm builds, and cleanup first
   # ...then chown at the end:
   chown -R "$PUID":"$PGID" /usr/local/apache2/htdocs
   chown -R "$PUID":"$PGID" /usr/local/apache2/logs
   ```

3. ✅ **Image repository handling** - No longer uses submodules, uses git cache instead:
   ```sh
   if [ -d /root/.cache/git/.git ]; then
       mkdir -p /usr/local/apache2/htdocs/img
       mv /root/.cache/git/.git /usr/local/apache2/htdocs/img/.git
       git -C /usr/local/apache2/htdocs/img fetch --depth=1 origin main && git -C /usr/local/apache2/htdocs/img reset --hard origin/main
       cleanup_working_img_directory
   else
       git clone --depth=1 "$IMG_LINK" /usr/local/apache2/htdocs/img
       cleanup_working_img_directory
   fi
   ```

4. ✅ **Git operations** - Uses `git clone --depth=1` for initial clone, version comparison to avoid unnecessary rebuilds

5. ✅ **Path handling in jq** - Uses full paths: `/usr/local/apache2/htdocs/package.json`

6. ✅ **Apache config syntax** - Uses `printf` with proper newline handling (not `echo`)

7. ✅ **Apache privilege dropping** - Uses Apache's native User/Group directives:
   ```sh
   sed -i "s/^User .*/User #$PUID/" /usr/local/apache2/conf/httpd.conf
   sed -i "s/^Group .*/Group #$PGID/" /usr/local/apache2/conf/httpd.conf
   ```

8. ✅ **Runtime build process** - npm ci + audit fix + build:sw:prod at container startup

9. ✅ **Build artifacts cleanup** - Removes .git, .github, node_modules after build for security

10. ✅ **Version detection** - Uses GitHub API via curl (not git commands)

11. ✅ **Git cache for images** - Reuses .git from `/root/.cache/git` to speed up updates

12. ✅ **CI/CD multi-arch** - QEMU and buildx setup steps present in workflow

13. ✅ **docker-compose.yml** - Points to GHCR: `ghcr.io/sakujakira/5etools-docker:latest`, uses named volumes

14. ✅ **.dockerignore** - Excludes .git, .github, .claude directories

15. ✅ **Trivy vulnerability scanning** - Automated security scanning on every push

16. ✅ **Dependabot configuration** - Automated dependency updates (daily Docker, weekly Actions)

**Security Status:**
- ✅ Apache worker processes run as non-root (PUID:PGID) - Apache handles privilege dropping natively
- ✅ Files owned by non-root user (PUID:PGID)
- ✅ Logs properly written to stdout/stderr (Docker logging best practice)
- ✅ `.dockerignore` prevents sensitive files in build context
- ✅ **Automated vulnerability scanning** with Trivy on every build
- ✅ **Automated dependency updates** with Dependabot (Docker + GitHub Actions)
- ✅ **Zero Critical/High CVEs** in latest local Trivy check (2026-02-15)
- ℹ️ Local spot-check numbers change over time (example on 2026-02-15: 2 total CVEs, 1 Medium, 1 Low with `--ignore-unfixed`)
- ✅ **Security visibility** via GitHub Security tab (SARIF reports)
- ⚠️ `/server-status` endpoint exposed to all IPs (information disclosure - consider restricting)
- ℹ️ Apache master process runs as root (standard practice, required for port binding and config reading)

## Branch Strategy

- `main` - Primary branch, triggers CI/CD builds and security scans

## Making Changes

**For Dockerfile changes:**
1. Test build locally first
2. Ensure shell script compatibility (Alpine uses busybox sh, not bash)
3. Keep line endings as LF (handled by .gitattributes)
4. Multi-arch builds may behave differently (especially ARM with QEMU)

**For init.sh changes:**
1. Use `#!/bin/sh` not `#!/bin/bash` (Alpine compatibility)
2. Test both update and offline modes
3. Test with both IMG=TRUE and IMG=FALSE
4. Test new environment variables (SEO_OPTION, NPM_AUDIT_FORCE_FIX)
5. Ensure file permissions work correctly with PUID/PGID
6. **Critical:** `chown` must happen AFTER all operations (git, npm builds, cleanup) to ensure proper file ownership
7. Apache httpd.conf User/Group directives must be set before starting httpd
8. **Build process:** npm ci → npm audit fix → npm run build:sw:prod → optional SEO build → cleanup
9. **Git cache:** Ensure img repository .git is properly cached/restored from `/root/.cache/git`
10. Test version comparison logic (local vs remote package.json)

**For docker-compose.yml changes:**
- Uses named volumes (htdocs, logs, git-cache) instead of host-mounted volumes
- Named volumes persist data between container restarts
- Use `docker-compose down -v` to remove volumes for clean slate
- New environment variables should be documented with comments
- `restart: unless-stopped` ensures container auto-restarts on failure

**For CI/CD changes:**
- Test with workflow_dispatch before merging
- Changes to .github/**, docker-compose.yml, *.md, .gitignore, .dockerignore are ignored by CI trigger (use workflow_dispatch)
- Documentation updates don't trigger builds automatically
