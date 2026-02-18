# 5etools-docker - Improvement TODO List

This document tracks planned improvements and enhancements for the project.

## High Priority

### Status: Open

#### Security & Automation
- [ ] **Create `SECURITY.md`**
  - Document security policy
  - Vulnerability reporting process
  - Security update timeline
  - Define supported versions and security maintenance window
  - Define security contact and responsible disclosure steps

#### Docker & Deployment
- [ ] **Enhance `docker-compose.yml` with best practices**
  - Add `restart: unless-stopped` policy
  - Add resource limits (CPU, memory)
  - Add logging configuration with rotation
  - Add healthcheck override if needed
  - Use named volumes for data and logs
  - Add container labels for organization
  - Add named network

- [ ] **Create `.env.example`**
  - Document all environment variables
  - Provide sensible defaults
  - Include usage examples

- [ ] **Document reverse proxy requirement**
  - Explicitly discourage direct internet exposure of the container
  - Recommend reverse proxy with SSL/TLS as the supported deployment pattern
  - Add a short security rationale (TLS, header handling, access control)

- [ ] **Replace simple HTTP healthcheck with state-aware validation**
  - Validate service readiness beyond "port responds"
  - Verify critical runtime state (download/build completed successfully)
  - Fail healthcheck when required files/state markers are missing
  - Keep the check fast and deterministic for container orchestrators

- [ ] **Use explicit readiness marker for container health**
  - Write marker only after successful download/build/init sequence
  - Reference marker in healthcheck/readiness logic
  - Clear marker before update/rebuild to avoid stale healthy state

- [ ] **Implement clean container stop process**
  - Handle `SIGTERM`/`SIGINT` explicitly in `init.sh`
  - Ensure Apache shuts down gracefully on container stop
  - Wait for child processes to exit cleanly within timeout
  - Exit with clear logs and predictable status codes

- [ ] **Make updates atomic with rollback safety**
  - Download/build in temporary working directory
  - Swap into live `htdocs` only after successful validation

#### CI/CD
- [ ] **Add basic container testing in CI**
  - Test container starts successfully
  - Verify healthcheck passes
  - Test with different PUID/PGID values
  - Test OFFLINE_MODE
  - Test `IMG=TRUE` and `IMG=FALSE`

#### Source Acquisition
- [ ] **Evaluate alternative static source strategies**
  - Compare GitHub repo clone vs GitHub artifacts vs `get.5e.tools`
  - Measure cold-start and warm-start download times
  - Measure reliability and failure behavior (timeouts, rate limits)
  - Evaluate reproducibility and version pinning options
  - Evaluate integrity verification options (checksum/signature)
  - Document recommendation with decision criteria and tradeoffs

- [ ] **Add experimental download mode switching**
  - Add `DOWNLOAD_MODE` env var (`git`, `artifact`, `get5e`)
  - Add a dedicated download function per mode in `init.sh`
  - Add fallback chain (`get5e` -> `artifact` -> `git`) if source fails
  - Add version and integrity validation after download
  - Log source mode, selected version, and elapsed download time

- [ ] **Add source comparison test matrix**
  - Test fresh volume vs pre-populated volume behavior
  - Test interaction with `OFFLINE_MODE`
  - Test with `IMG=TRUE` and `IMG=FALSE`
  - Test with custom `PUID`/`PGID`
  - Simulate network failure and verify fallback behavior

- [ ] **Add strict `OFFLINE_MODE` guardrails**
  - Fail fast when required files are missing in offline mode
  - Print clear remediation steps in logs

- [ ] **Support source/version pinning**
  - Allow pinning to explicit version/tag/commit for reproducible deployments
  - Record resolved version in startup logs

### Status: Completed

#### Core Platform
- [x] Migrate from Debian to Alpine Linux
- [x] Upgrade to `httpd:2-alpine` for latest security patches
- [x] Implement Apache-native privilege dropping
- [x] Fix file ownership timing
- [x] Fix Apache config syntax

#### Security & Automation
- [x] Achieve zero critical/high CVEs
- [x] Add `.dockerignore`
- [x] Add Dependabot configuration (daily Docker checks, weekly GitHub Actions)
- [x] Add Trivy container scanning to CI/CD pipeline
- [x] Integrate GitHub Security tab with SARIF uploads

## Medium Priority

### Status: Open

#### Documentation
- [ ] **Add GitHub issue templates**
  - Bug report template (`.github/ISSUE_TEMPLATE/bug_report.yml`)
  - Feature request template (`.github/ISSUE_TEMPLATE/feature_request.yml`)
  - Question template

- [ ] **Add Pull Request template**
  - Standardize PR descriptions
  - Checklist for contributors
  - Testing verification steps

- [ ] **Create `CONTRIBUTING.md`**
  - Contribution guidelines
  - Code style requirements
  - How to test changes
  - PR submission process

- [ ] **Add examples directory**
  - Example docker-compose configurations
  - Reverse proxy examples (`linuxserver/swag`, Caddy, Traefik)
  - Different deployment scenarios

- [ ] **Add reverse proxy hardening guidance**
  - Trusted proxy/header configuration examples
  - TLS best practices and redirect policy
  - Optional access control examples (e.g., basic auth)

#### Developer Experience
- [ ] **Create Makefile**
  - `make build` - Build image locally
  - `make test` - Run tests
  - `make run` - Start with docker-compose
  - `make clean` - Clean up containers/volumes
  - `make scan` - Run security scan

- [ ] **Add docker-compose.prod.yml**
  - Production-specific overrides
  - Stricter resource limits
  - Better logging configuration
  - Always restart policy

#### CI/CD
- [ ] **Add release automation**
  - Semantic versioning tags
  - Automated changelog generation
  - GitHub Releases with build artifacts
  - Release notes template

- [ ] **Improve multi-arch build**
  - Optimize build caching
  - Parallel builds if possible
  - Build time optimization

### Status: Completed

#### CI/CD
- [x] Add multi-arch support (amd64, arm64)

#### Repository Hygiene
- [x] Add `.gitignore`

#### Documentation
- [x] Create comprehensive `CLAUDE.md` documentation
- [x] Add README comparison section with CVE data
- [x] Add security section to README

## Low Priority

### Status: Open

#### Scripts & Utilities
- [ ] **Create scripts directory**
  - `backup.sh` - Backup htdocs data
  - `restore.sh` - Restore from backup
  - `update.sh` - Pull latest image and restart
  - `health-check.sh` - Manual health verification
  - `clean-old-images.sh` - Clean up old Docker images

#### Monitoring & Observability
- [ ] **Add structured logging**
  - JSON formatted logs
  - Consistent log levels
  - Better error messages

- [ ] **Add Prometheus metrics** (optional)
  - Apache exporter integration
  - Custom metrics for git operations
  - Container resource metrics

- [ ] **Add monitoring examples**
  - Grafana dashboard example
  - Prometheus configuration
  - Alert rules

#### Advanced Features
- [ ] **Add backup/restore functionality**
  - Automated backup scheduling
  - S3 backup support
  - Restore from backup script

- [ ] **Add update notification system**
  - Check for 5etools updates
  - Optional webhook notifications
  - Email notifications

- [ ] **Add development environment**
  - `docker-compose.dev.yml` for local development
  - Hot reload for testing
  - Debug mode

### Status: Completed

#### Documentation
- [x] Add AI-assisted development disclaimer

## Operational Checklists

### Testing Checklist
When implementing changes, verify:

- [ ] Container builds successfully
- [ ] Container starts and passes healthcheck
- [ ] Apache runs as non-root (PUID/PGID)
- [ ] Files are owned correctly
- [ ] Git operations work (clone, pull, submodules)
- [ ] OFFLINE_MODE works
- [ ] Multi-arch build succeeds
- [ ] CVE count remains low

### Before Each Release
- [ ] Update `CLAUDE.md` if architecture changes
- [ ] Update `README.md` with any new features
- [ ] Run full security scan
- [ ] Test on both architectures
- [ ] Update version numbers if applicable
- [ ] Create git tag
- [ ] Update changelog

## Contributing

If you'd like to help with any of these items:
1. Comment on or create an issue for the item
2. Fork the repository
3. Create a feature branch
4. Submit a pull request

Last Updated: 2026-02-18
Maintainer: Sakujakira
