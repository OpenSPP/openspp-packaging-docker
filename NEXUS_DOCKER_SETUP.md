# Nexus Docker Registry Configuration

## Overview

This document describes the Nexus Docker registry setup for OpenSPP images and how to configure Woodpecker CI to push images successfully.

## Registry Endpoints

The Nexus repository uses different endpoints for different purposes:

- **Internal Docker Registry**: `172.20.0.26:8082` (within Docker network)
- **Public Pull Access**: `docker.acn.fr` (public read-only)
- **Push Access**: `docker-push.acn.fr` (requires authentication)

## Authentication Issues and Solutions

### Problem: Plugin Authentication Failures

The `woodpeckerci/plugin-docker-buildx` plugin often fails to authenticate with Nexus when using the plugin's built-in authentication mechanism.

### Solution: Use Explicit Docker Commands

Based on the working pattern from `openspp-packaging-v2`, use explicit Docker commands with manual login:

```yaml
steps:
  build-and-push:
    image: docker:latest
    privileged: true
    environment:
      NEXUS_USER:
        from_secret: nexus_username
      NEXUS_PASS:
        from_secret: nexus_password
    commands:
      # Login explicitly
      - echo "$NEXUS_PASS" | docker login 172.20.0.26:8082 -u "$NEXUS_USER" --password-stdin
      
      # Build and push with buildx
      - docker buildx create --use --name mybuilder
      - docker buildx build --platform linux/amd64,linux/arm64 --push -t 172.20.0.26:8082/openspp/openspp:latest .
```

## Woodpecker Secrets Configuration

### Required Secrets

Add these secrets to your Woodpecker repository settings:

1. **nexus_username** or **nexus_user**: Your Nexus username
2. **nexus_password**: Your Nexus password

Note: Different projects may use different secret names. The working configuration checks for both:
- `nexus_username` (newer convention)
- `nexus_user` (older convention)

### Adding Secrets via Woodpecker CLI

```bash
# Add secrets
woodpecker secret add openspp/openspp-packaging-docker \
  --name nexus_username \
  --value "your-username"

woodpecker secret add openspp/openspp-packaging-docker \
  --name nexus_password \
  --value "your-password"
```

### Adding Secrets via UI

1. Navigate to your repository in Woodpecker UI
2. Go to Settings → Secrets
3. Add the required secrets

## Network Configuration

### Internal Network Access

The Nexus server is accessible at `172.20.0.26` within the Docker platform network:
- Port 8081: APT repository
- Port 8082: Docker registry

### Testing Connectivity

Test from within a Woodpecker pipeline:

```yaml
test-connection:
  image: alpine:latest
  commands:
    - apk add --no-cache curl
    - curl -I http://172.20.0.26:8082/v2/
```

## Working Configuration Example

See `.woodpecker-working.yml` for a complete working example that:
1. Uses explicit Docker commands
2. Handles authentication properly
3. Supports multi-architecture builds
4. Manages different tags for different events (tag, cron, push)

## Manual Push Script

Use `ci-docker-push.sh` for manual pushing:

```bash
# Set credentials
export NEXUS_USER="your-username"
export NEXUS_PASSWORD="your-password"

# Build image
docker build -t openspp:latest .

# Push to Nexus
./ci-docker-push.sh openspp:latest
```

## Troubleshooting

### Authentication Failures

1. **Check secret names**: Ensure using the correct secret names (nexus_username vs nexus_user)
2. **Verify credentials**: Test login manually:
   ```bash
   echo "your-password" | docker login 172.20.0.26:8082 -u "your-username" --password-stdin
   ```
3. **Check network access**: Ensure the CI runner can reach 172.20.0.26:8082

### Push Failures

1. **Repository exists**: Verify the repository `openspp/openspp` exists in Nexus
2. **User permissions**: Ensure the user has push permissions
3. **Image size**: Check if there are size limits in Nexus

### Registry Not Accessible

If `172.20.0.26:8082` is not accessible:
1. Verify you're within the Docker platform network
2. Check if the Nexus container is running
3. Verify port 8082 is the correct Docker registry port

## Best Practices

1. **Use explicit Docker commands** instead of relying on plugin authentication
2. **Test locally first** using the manual push script
3. **Use internal IPs** (172.20.0.26) for CI/CD within the Docker network
4. **Tag appropriately** based on build events (tag, cron, branch)
5. **Handle both secret naming conventions** for compatibility

## References

- Working example: `/Users/jeremi/Projects/134-openspp/openspp-packaging-v2/.woodpecker.yml`
- Nexus Docker Registry API: https://help.sonatype.com/repomanager3/integrations/docker-registry
- Docker Buildx Documentation: https://docs.docker.com/buildx/working-with-buildx/