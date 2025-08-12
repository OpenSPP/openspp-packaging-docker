# CI/CD Setup Guide for Woodpecker

## Prerequisites

### Server Configuration

The OpenSPP Docker build pipeline uses `woodpeckerci/plugin-docker-buildx` for multi-architecture builds. This plugin requires privileged mode to run Docker-in-Docker operations.

#### Required Environment Variable

Add the following to your Woodpecker server configuration:

```bash
WOODPECKER_PLUGINS_PRIVILEGED=woodpeckerci/plugin-docker-buildx
```

This can be set in:
- Docker Compose: Add to the `environment` section of the Woodpecker server service
- Kubernetes: Add to the ConfigMap or environment variables
- Systemd: Add to the service file or environment file
- Direct execution: Export before starting the server

### Secrets Configuration

The pipeline requires the following secrets to be configured in Woodpecker:

1. **Docker Registry Credentials** (for pushing images):
   - `docker_username`: Docker Hub or registry username
   - `docker_password`: Docker Hub or registry password/token

2. **Production Registry Credentials** (optional, for production deployments):
   - `prod_docker_username`: Production registry username
   - `prod_docker_password`: Production registry password/token

3. **Slack Webhook** (optional, for notifications):
   - `slack_webhook`: Slack webhook URL for build notifications

### Setting Secrets in Woodpecker

Using the Woodpecker CLI:
```bash
woodpecker secret add -repository openspp/openspp-packaging-docker \
  -name docker_username \
  -value "your-docker-username"

woodpecker secret add -repository openspp/openspp-packaging-docker \
  -name docker_password \
  -value "your-docker-password"
```

Or via the Woodpecker UI:
1. Navigate to your repository settings
2. Go to "Secrets" section
3. Add each secret with the appropriate name and value

## Alternative: Non-Privileged Build

If you cannot enable privileged mode on your Woodpecker server, you can use the alternative build steps provided in the pipeline:

1. Edit `.woodpecker.yml`
2. Comment out the `build-docker-ubuntu` and `build-docker-slim` steps
3. Uncomment the `build-docker-ubuntu-alt` step (and create a similar one for slim)
4. Note: This alternative method:
   - Only builds for the current architecture (no multi-arch support)
   - Doesn't support BuildKit cache optimization
   - May be slower for large images

## Troubleshooting

### Error: "Plugin requires privileged mode"

**Solution**: Ensure `WOODPECKER_PLUGINS_PRIVILEGED` is set on the server and restart the Woodpecker server.

### Error: "Cannot connect to Docker daemon"

**Solution**: The plugin needs Docker-in-Docker. Ensure:
1. The plugin is in privileged mode
2. The Woodpecker agent has access to Docker socket or Docker-in-Docker is properly configured

### Build fails with "unauthorized"

**Solution**: Check that:
1. Docker credentials secrets are properly configured
2. The credentials have push access to the target repository
3. The registry URL is correct in the pipeline configuration

## Pipeline Workflow

The pipeline executes the following steps:

1. **Security Scan**: Scans repository for vulnerabilities using Trivy
2. **Build Ubuntu Image**: Builds multi-arch image based on Ubuntu 24.04
3. **Build Slim Image**: Builds multi-arch image based on Debian bookworm-slim
4. **Scan Images**: Security scan of built Docker images
5. **Test Images**: Basic functionality tests
6. **Push to Production** (tags only): Pushes images to production registry
7. **Update Manifests** (tags only): Updates Kubernetes deployment manifests
8. **Notify**: Sends Slack notification about build status

## Supported Events

The pipeline triggers on:
- **Push**: To main, master, develop, or release/* branches
- **Pull Request**: For testing changes
- **Tag**: For production releases

## Environment Variables

The pipeline uses these CI variables (automatically provided by Woodpecker):
- `CI_REGISTRY`: Docker registry URL
- `CI_REPO_OWNER`: Repository owner/organization
- `CI_COMMIT_TAG`: Git tag (for releases)
- `CI_COMMIT_BRANCH`: Git branch name
- `CI_COMMIT_SHA`: Git commit hash
- `CI_BUILD_CREATED`: Build timestamp
- `PROD_REGISTRY`: Production registry URL (optional)