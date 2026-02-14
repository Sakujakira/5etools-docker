# 5etools-docker - Improvement TODO List

This document tracks planned improvements and enhancements for the project.

## 🔥 High Priority (Quick Wins)

### Security & Automation
- [ ] **Add Dependabot configuration** (.github/dependabot.yml)
  - Auto-update Docker base image
  - Weekly checks for security updates
  - Auto-create PRs for dependency updates

- [ ] **Add container scanning to CI/CD**
  - Integrate Trivy or Grype scanner
  - Scan on every PR and push
  - Fail builds on critical/high CVEs
  - Upload results to GitHub Security tab

- [ ] **Create SECURITY.md**
  - Document security policy
  - Vulnerability reporting process
  - Security update timeline

### Docker & Deployment
- [ ] **Enhance docker-compose.yml with best practices**
  - Add `restart: unless-stopped` policy
  - Add resource limits (CPU, memory)
  - Add logging configuration with rotation
  - Add healthcheck override if needed
  - Use named volumes for data and logs
  - Add container labels for organization
  - Add named network

- [ ] **Create .env.example**
  - Document all environment variables
  - Provide sensible defaults
  - Include usage examples

### CI/CD
- [ ] **Add basic container testing in CI**
  - Test container starts successfully
  - Verify healthcheck passes
  - Test with different PUID/PGID values
  - Test OFFLINE_MODE

---

## 📋 Medium Priority

### Documentation
- [ ] **Add GitHub issue templates**
  - Bug report template (.github/ISSUE_TEMPLATE/bug_report.yml)
  - Feature request template (.github/ISSUE_TEMPLATE/feature_request.yml)
  - Question template

- [ ] **Add Pull Request template**
  - Standardize PR descriptions
  - Checklist for contributors
  - Testing verification steps

- [ ] **Create CONTRIBUTING.md**
  - Contribution guidelines
  - Code style requirements
  - How to test changes
  - PR submission process

- [ ] **Add examples directory**
  - Example docker-compose configurations
  - Reverse proxy examples (Traefik, Nginx)
  - Different deployment scenarios

### Developer Experience
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

### CI/CD Enhancements
- [ ] **Add release automation**
  - Semantic versioning tags
  - Automated changelog generation
  - GitHub Releases with build artifacts
  - Release notes template

- [ ] **Improve multi-arch build**
  - Optimize build caching
  - Parallel builds if possible
  - Build time optimization

---

## 🎯 Low Priority (Nice to Have)

### Scripts & Utilities
- [ ] **Create scripts directory**
  - `backup.sh` - Backup htdocs data
  - `restore.sh` - Restore from backup
  - `update.sh` - Pull latest image and restart
  - `health-check.sh` - Manual health verification
  - `clean-old-images.sh` - Clean up old Docker images

### Monitoring & Observability
- [ ] **Add structured logging**
  - JSON formatted logs
  - Consistent log levels
  - Better error messages

- [ ] **Add Prometheus metrics** (Optional)
  - Apache exporter integration
  - Custom metrics for git operations
  - Container resource metrics

- [ ] **Add monitoring examples**
  - Grafana dashboard example
  - Prometheus configuration
  - Alert rules

### Advanced Features
- [ ] **Add backup/restore functionality**
  - Automated backup scheduling
  - S3 backup support
  - Restore from backup script

- [ ] **Add update notification system**
  - Check for 5etools updates
  - Optional webhook notifications
  - Email notifications

- [ ] **Add development environment**
  - docker-compose.dev.yml for local development
  - Hot reload for testing
  - Debug mode

---

## ✅ Completed

- [x] Migrate from Debian to Alpine Linux
- [x] Implement Apache-native privilege dropping
- [x] Fix file ownership timing
- [x] Fix Apache config syntax
- [x] Add multi-arch support (amd64, arm64)
- [x] Add .dockerignore
- [x] Add .gitignore
- [x] Create comprehensive CLAUDE.md documentation
- [x] Add README comparison section with CVE data
- [x] Add security section to README
- [x] Add AI-assisted development disclaimer
- [x] Upgrade to httpd:2-alpine for latest security patches
- [x] Achieve zero critical/high CVEs

---

## 📝 Notes

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
- [ ] Update CLAUDE.md if architecture changes
- [ ] Update README.md with any new features
- [ ] Run full security scan
- [ ] Test on both architectures
- [ ] Update version numbers if applicable
- [ ] Create git tag
- [ ] Update changelog

---

## 🤝 Contributing

If you'd like to help with any of these items:
1. Comment on or create an issue for the item
2. Fork the repository
3. Create a feature branch
4. Submit a pull request

---

*Last Updated: 2026-02-14*
*Maintainer: Sakujakira*
