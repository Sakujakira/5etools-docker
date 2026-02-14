# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Docker containerization of 5etools (D&D 5th edition tools) based on Alpine Linux with Apache httpd. The container automatically clones/updates the 5etools repository from GitHub and serves it via Apache.

## Architecture

**Container Startup Flow:**
1. `init.sh` is the entry point (CMD in Dockerfile), runs as root
2. Creates dynamic user/group (appuser/appgroup) based on PUID/PGID environment variables
3. Either runs in OFFLINE_MODE (uses existing files) or clones/updates from GitHub
4. Optionally adds images as git submodule if IMG=TRUE
5. Completes all git operations as root (required for permissions)
6. Sets ownership of htdocs and logs directories to PUID:PGID (after all git operations)
7. Modifies Apache httpd.conf to set User/Group directives to PUID/PGID
8. Starts `httpd-foreground` as root - Apache master runs as root, workers drop to PUID:PGID

**Key Paths:**
- `/usr/local/apache2/htdocs/` - Web root, mapped to host volume for persistence
- `/init.sh` - Container entry point script

**Base Image:** `httpd:alpine3.20` (Alpine-based Apache)

**Source Repositories:**
- Main content: `https://github.com/5etools-mirror-3/5etools-src.git`
- Images (optional): `https://github.com/5etools-mirror-3/5etools-img.git`
- Note: Project uses mirror-3 repositories (updated from mirror-2)

## Common Commands

### Local Development & Testing

```bash
# Quick start with default configuration
mkdir -p ~/5etools-docker/htdocs && cd ~/5etools-docker
docker-compose up -d && docker logs -f 5etools-docker

# Stop and remove container (files persist in htdocs)
docker-compose down

# Build image locally
docker build -t 5etools-docker .

# Build with custom PUID/PGID
docker build --build-arg PUID=1001 --build-arg PGID=1001 -t 5etools-docker .

# Test with images enabled
docker run -d -p 8080:80 -e IMG=TRUE -v ~/5etools-docker/htdocs:/usr/local/apache2/htdocs 5etools-docker

# Test offline mode
docker run -d -p 8080:80 -e OFFLINE_MODE=TRUE -v ~/5etools-docker/htdocs:/usr/local/apache2/htdocs 5etools-docker

# Monitor container startup (useful for debugging)
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

# Test container with custom PUID/PGID
docker run -d --name test -p 8080:80 -e PUID=1001 -e PGID=1001 \
  -v ~/5etools-docker/htdocs:/usr/local/apache2/htdocs <image>

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
- Builds multi-arch images (linux/amd64, linux/arm64)
- Pushes to GHCR (`ghcr.io/<repo>`) and Docker Hub (`docker.io/<username>/5etools-docker`)
- Triggers on push to main branch (excluding changes to .github/**, docker-compose.yml, README.md)
- Can be manually triggered via workflow_dispatch
- **Note:** Multi-arch builds require QEMU and buildx setup steps (verify these are present in workflow)

**Required GitHub Secrets:**
- `DOCKERHUB_USERNAME` - Docker Hub username
- `DOCKERHUB_TOKEN` - Docker Hub access token
- `GITHUB_TOKEN` - Automatically provided by GitHub Actions

## Environment Variables

- `PUID` / `PGID` (default: 1000) - User/group ID for file ownership
- `DL_LINK` (default: https://github.com/5etools-mirror-3/5etools-src.git) - Source repository
- `IMG_LINK` (default: https://github.com/5etools-mirror-3/5etools-img.git) - Image repository
- `IMG` (TRUE/FALSE) - Whether to pull image files as git submodule
- `OFFLINE_MODE` (TRUE to enable) - Skip GitHub updates, use existing files

## Critical Implementation Details

**init.sh script:**
- Uses `set -e` to exit on any error
- Creates user/group dynamically (idempotent with `2>/dev/null || true` to handle container restarts)
- Uses `jq` to extract version from package.json (with full paths and error handling)
- Configures git with safe.directory to handle mounted volumes
- Uses shallow clone (`--depth=1`) for faster updates
- Git operations: `git reset --hard origin/HEAD` + `git pull origin main --depth=1` (no bare `git checkout`)
- Handles git submodule for images (IMG=TRUE) - checks if `./img/.git` exists before adding
- **Critical:** Sets ownership of htdocs and logs directories to PUID:PGID AFTER all git operations complete
- Modifies Apache httpd.conf User/Group directives via `sed` to match PUID/PGID
- Starts `httpd-foreground` (Apache master as root, workers as PUID:PGID - Apache's native privilege dropping)
- Always runs `httpd-foreground` to keep container alive

**Dockerfile:**
- Cleans htdocs directory with safe pattern: `rm -rf * .[!.]* ..?*` (excludes . and ..)
- Uses `COPY --chmod=755` for init.sh to ensure executability
- Installs minimal dependencies: git, jq, su-exec (shadow package not needed - Alpine uses busybox adduser/addgroup)
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

2. ✅ **File ownership timing** - `chown` executes AFTER all git operations (critical for proper ownership):
   ```sh
   # All git operations first (clone, reset, pull)
   # ...then chown at the end:
   chown -R "$PUID":"$PGID" /usr/local/apache2/htdocs
   chown -R "$PUID":"$PGID" /usr/local/apache2/logs
   ```

3. ✅ **Git submodule handling** - Checks for existing submodule before adding:
   ```sh
   if [ ! -d "./img/.git" ]; then
       git submodule add --depth=1 -f "$IMG_LINK" /usr/local/apache2/htdocs/img
   else
       git submodule update --remote --depth=1
   fi
   ```

4. ✅ **Git operations** - Uses `git reset --hard origin/HEAD` + `git pull origin main --depth=1`

5. ✅ **Path handling in jq** - Uses full paths: `/usr/local/apache2/htdocs/package.json`

6. ✅ **Apache config syntax** - Uses `printf` with proper newline handling (not `echo`)

7. ✅ **Apache privilege dropping** - Uses Apache's native User/Group directives:
   ```sh
   sed -i "s/^User .*/User #$PUID/" /usr/local/apache2/conf/httpd.conf
   sed -i "s/^Group .*/Group #$PGID/" /usr/local/apache2/conf/httpd.conf
   ```

8. ✅ **CI/CD multi-arch** - QEMU and buildx setup steps present in workflow

9. ✅ **docker-compose.yml** - Points to GHCR: `ghcr.io/sakujakira/5etools-docker:latest`

10. ✅ **.dockerignore** - Excludes .git, .github, .claude directories

**Security Status:**
- ✅ Apache worker processes run as non-root (PUID:PGID) - Apache handles privilege dropping natively
- ✅ Files owned by non-root user (PUID:PGID)
- ✅ Logs properly written to stdout/stderr (Docker logging best practice)
- ✅ `.dockerignore` prevents sensitive files in build context
- ⚠️ `/server-status` endpoint exposed to all IPs (information disclosure - consider restricting)
- ℹ️ Apache master process runs as root (standard practice, required for port binding and config reading)

## Branch Strategy

- `main` - Primary branch, triggers CI/CD builds
- `alpine` - Current development branch (branch context for this session)

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
4. Ensure file permissions work correctly with PUID/PGID
5. **Critical:** `chown` must happen AFTER all git operations to ensure proper file ownership
6. Apache httpd.conf User/Group directives must be set before starting httpd

**For CI/CD changes:**
- Test with workflow_dispatch before merging
- Changes to .github/** are ignored by CI trigger (use workflow_dispatch)
