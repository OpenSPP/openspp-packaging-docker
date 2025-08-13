# Woodpecker CI Fix for Nexus Docker Push

## Quick Fix

To fix the Woodpecker build that's failing to push to Nexus:

```bash
# Use the working configuration
cp .woodpecker-working.yml .woodpecker.yml

# Commit and push
git add .woodpecker.yml
git commit -m "fix: use explicit Docker commands for Nexus push"
git push
```

## What Was Wrong

The original configuration tried to use the `woodpeckerci/plugin-docker-buildx` plugin's built-in authentication, which doesn't work properly with our Nexus setup. The plugin fails to authenticate even with correct credentials.

## What Was Fixed

The new configuration (`.woodpecker-working.yml`) uses the same pattern as the working `openspp-packaging-v2` project:

1. **Explicit Docker login** instead of plugin authentication
2. **Direct buildx commands** instead of plugin settings
3. **Internal IP address** (172.20.0.26:8082) for the Docker registry
4. **Fallback secret names** (supports both nexus_username and nexus_user)

## Key Changes

### Before (Not Working)
```yaml
build:
  image: woodpeckerci/plugin-docker-buildx
  settings:
    username:
      from_secret: nexus_username
    password:
      from_secret: nexus_password
    registry: docker-push.acn.fr
    # ... plugin handles login internally
```

### After (Working)
```yaml
build:
  image: docker:latest
  commands:
    # Explicit login
    - echo "$NEXUS_PASS" | docker login 172.20.0.26:8082 -u "$NEXUS_USER" --password-stdin
    # Direct buildx commands
    - docker buildx build --push -t 172.20.0.26:8082/openspp/openspp:latest .
```

## Required Secrets

Ensure these secrets are configured in Woodpecker:
- `nexus_username` or `nexus_user`
- `nexus_password`

## Testing Locally

Test the Docker push manually:

```bash
# Set credentials
export NEXUS_USER="your-username"
export NEXUS_PASSWORD="your-password"

# Build image
docker build -t openspp:latest .

# Test push
./ci-docker-push.sh openspp:latest
```

## Files Created

- `.woodpecker-working.yml` - Working CI configuration
- `ci-docker-push.sh` - Manual push script for testing
- `NEXUS_DOCKER_SETUP.md` - Complete documentation

## Next Steps

1. Replace `.woodpecker.yml` with `.woodpecker-working.yml`
2. Ensure secrets are configured in Woodpecker
3. Push changes to trigger a build
4. Monitor the build logs for success