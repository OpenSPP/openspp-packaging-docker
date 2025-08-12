# Woodpecker CI Authentication Troubleshooting

## Issue
The Woodpecker CI pipeline is failing with authentication errors when trying to push to the Nexus Docker registry:
```
Logging in with username '********' to registry 'docker-push.acn.fr'
ERR execution failed error="error authenticating: exit status 1"
```

## Possible Causes

### 1. Secret Names Mismatch
The GitHub Actions workflow uses uppercase secret names:
- `NEXUS_USERNAME`
- `NEXUS_PASSWORD`

While Woodpecker configuration uses lowercase:
- `nexus_username`
- `nexus_password`

**Solution**: Ensure secrets are configured in Woodpecker with the exact same names used in the pipeline.

### 2. Secret Configuration in Woodpecker
Secrets need to be properly configured in Woodpecker either:
- **Repository secrets**: Add via Woodpecker UI under repository settings
- **Organization secrets**: Add at organization level if using shared credentials
- **Global secrets**: Configure in Woodpecker server for all repositories

**To add secrets in Woodpecker UI:**
1. Go to your repository in Woodpecker
2. Click on Settings → Secrets
3. Add new secrets:
   - Name: `nexus_username` (or `NEXUS_USERNAME`)
   - Value: Your Nexus username
   - Name: `nexus_password` (or `NEXUS_PASSWORD`)
   - Value: Your Nexus password

### 3. Plugin Authentication Format
The `woodpeckerci/plugin-docker-buildx` plugin might have issues with certain authentication methods.

**Alternative approaches provided:**

#### Option A: Debug Configuration (`.woodpecker-debug.yml`)
Use this to test secret availability and manual Docker login:
```bash
# Rename to .woodpecker.yml to test
mv .woodpecker-debug.yml .woodpecker.yml
```

#### Option B: Alternative Configuration (`.woodpecker-alt.yml`)
Uses Docker commands directly instead of the plugin:
```bash
# Rename to .woodpecker.yml to use
mv .woodpecker-alt.yml .woodpecker.yml
```

### 4. Registry URL Format
Ensure the registry URL is correct:
- Push URL: `docker-push.acn.fr`
- Pull URL: `docker.acn.fr`

### 5. Permissions
The repository must be marked as "Trusted" in Woodpecker to use privileged mode required for Docker builds.

## Testing Steps

1. **Test secret availability:**
   ```bash
   # Use the debug configuration
   cp .woodpecker-debug.yml .woodpecker.yml
   git commit -m "test: debug authentication"
   git push
   ```

2. **Check Woodpecker logs:**
   - Look for the "test-secrets" step output
   - Verify secrets are being passed (non-zero length)

3. **Try manual authentication:**
   - The "test-docker-login" step will test direct Docker login
   - This helps identify if it's a plugin issue or credential issue

4. **Use alternative configuration:**
   If the plugin continues to fail, use the alternative configuration that bypasses the plugin.

## Working GitHub Actions Reference
The GitHub Actions workflow (`.github/workflows/docker-build.yml`) successfully authenticates using:
```yaml
- name: Log in to Nexus Registry
  uses: docker/login-action@v3
  with:
    registry: docker-push.acn.fr
    username: ${{ secrets.NEXUS_USERNAME }}
    password: ${{ secrets.NEXUS_PASSWORD }}
```

## Recommended Solution Path

1. First, ensure secrets are properly configured in Woodpecker UI
2. Try the debug configuration to verify secrets are accessible
3. If plugin authentication fails, switch to the alternative configuration
4. Once working, optimize the configuration as needed

## Additional Notes

- The plugin might require specific versions or configurations
- Consider using Woodpecker's native Docker plugin if available
- Check Woodpecker server logs for more detailed error messages
- Verify network connectivity from Woodpecker runner to Nexus registry