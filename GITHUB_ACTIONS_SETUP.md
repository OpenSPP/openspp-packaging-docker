# GitHub Actions Setup Guide

## Overview

This repository uses GitHub Actions for CI/CD to build and push OpenSPP Docker images to the ACN Nexus Docker Registry.

## Required Secrets

Configure the following secrets in your GitHub repository settings:

### Registry Authentication
- `NEXUS_USERNAME`: Nexus registry username (e.g., `admin`)
- `NEXUS_PASSWORD`: Nexus registry password

### Optional Notifications
- `SLACK_WEBHOOK`: Slack webhook URL for build notifications (optional)

### Setting Secrets

1. Go to your repository on GitHub
2. Navigate to **Settings** > **Secrets and variables** > **Actions**
3. Click **New repository secret**
4. Add each secret:
   - Name: `NEXUS_USERNAME`
   - Value: Your Nexus username
   - Click **Add secret**
   - Repeat for `NEXUS_PASSWORD` and optionally `SLACK_WEBHOOK`

## Workflows

### 1. Docker Build and Push (`docker-build.yml`)

**Triggers:**
- Push to main, master, develop, or release/* branches
- Pull requests to main, master, or develop
- Git tags (v*, semantic versioning)
- Manual workflow dispatch

**Actions:**
- Builds Ubuntu 24.04 and Debian slim Docker images
- **Platform:** linux/amd64 only (no ARM support)
- Pushes to Nexus registry (`docker-push.acn.fr`)
- Images available publicly at `docker.acn.fr/openspp/openspp`
- Runs tests on pull requests
- Updates Kubernetes manifests on tag releases

**Image Tags:**
- `latest` / `latest-slim` - Latest from main branch
- `daily` / `daily-slim` - Daily builds from main branch
- `v1.0.0` / `v1.0.0-slim` - Version tags
- `develop-sha123abc` - Branch with commit SHA
- `pr-123` - Pull request builds

### 2. Security Scan (`security-scan.yml`)

**Triggers:**
- Push to main branches
- Pull requests
- Daily at 2 AM UTC
- Manual workflow dispatch

**Actions:**
- Trivy vulnerability scanning
- Hadolint Dockerfile linting
- OWASP dependency checking
- Results uploaded to GitHub Security tab

## Usage

### Manual Build

1. Go to **Actions** tab in your repository
2. Select **Docker Build and Push** workflow
3. Click **Run workflow**
4. Choose branch and whether to push images
5. Click **Run workflow** button

### Automatic Builds

Images are automatically built and pushed when:
- Pushing to main/master/develop branches
- Creating a new release tag
- Changes are tested (but not pushed) on pull requests

## Registry Information

### Push Registry (Authentication Required)
```
docker-push.acn.fr/openspp/openspp
```

### Public Registry (Anonymous Pull)
```
docker.acn.fr/openspp/openspp
```

## Pulling Images

After images are built and pushed, they're available at:

```bash
# Latest stable
docker pull docker.acn.fr/openspp/openspp:latest
docker pull docker.acn.fr/openspp/openspp:latest-slim

# Daily builds
docker pull docker.acn.fr/openspp/openspp:daily
docker pull docker.acn.fr/openspp/openspp:daily-slim

# Specific version
docker pull docker.acn.fr/openspp/openspp:v1.0.0
docker pull docker.acn.fr/openspp/openspp:v1.0.0-slim
```

## Build Status

You can view build status in the **Actions** tab of your repository. Each workflow run shows:
- Build logs
- Test results
- Security scan findings
- Artifacts (if any)

## Troubleshooting

### Authentication Failures

If builds fail with authentication errors:
1. Verify `NEXUS_USERNAME` and `NEXUS_PASSWORD` secrets are set correctly
2. Test credentials locally:
   ```bash
   docker login docker-push.acn.fr -u <username>
   ```

### Build Failures

1. Check the workflow logs in the Actions tab
2. Common issues:
   - APT repository connectivity
   - Package installation failures
   - Dockerfile syntax errors

### Security Scan Issues

Security scans may find vulnerabilities. Check:
1. **Security** tab for detailed reports
2. Trivy results in workflow logs
3. Consider updating base images or packages

## Architecture

- **Build Platform:** linux/amd64 only
- **Base Images:**
  - Ubuntu: `ubuntu:24.04`
  - Slim: `debian:bookworm-slim`
- **OpenSPP Source:** APT repository at https://builds.acn.fr/repository/apt-openspp-daily/

## Monitoring

### Build Notifications

If `SLACK_WEBHOOK` is configured, you'll receive notifications for:
- Successful builds
- Failed builds
- Security scan results

### GitHub Notifications

Enable GitHub notifications to receive updates about:
- Workflow failures
- Security alerts
- Pull request checks

## Best Practices

1. **Always test in pull requests** before merging to main
2. **Review security scan results** regularly
3. **Tag releases** properly for production deployments
4. **Monitor build times** and optimize if needed
5. **Keep secrets secure** and rotate regularly

## Support

For issues with:
- **GitHub Actions:** Check [GitHub Actions documentation](https://docs.github.com/actions)
- **Docker builds:** Review Dockerfile and build logs
- **Nexus registry:** Contact your Nexus administrator
- **OpenSPP packages:** Check APT repository status