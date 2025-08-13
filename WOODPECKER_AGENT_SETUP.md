# Woodpecker Agent Setup for Docker Builds

## Requirements

The Woodpecker agent host must be configured to support building and pushing Docker images to the Nexus registry at `172.20.0.26:8082`.

## Required Configuration

### 1. Docker Installed

The Woodpecker agent must have Docker installed and running:

```bash
# Verify Docker is installed
docker --version
```

### 2. Insecure Registry Configuration

Since the Nexus Docker registry at `172.20.0.26:8082` uses HTTP (not HTTPS), the Docker daemon on the Woodpecker agent host must be configured to allow this insecure registry.

#### Edit Docker daemon configuration:

```bash
sudo nano /etc/docker/daemon.json
```

Add or update the configuration:

```json
{
  "insecure-registries": ["172.20.0.26:8082"]
}
```

#### Restart Docker:

```bash
sudo systemctl restart docker
```

#### Verify the configuration:

```bash
docker info | grep -A 5 "Insecure Registries"
```

You should see `172.20.0.26:8082` listed.

### 3. Docker Socket Access

The Woodpecker agent must have access to the Docker socket. This is typically at `/var/run/docker.sock`.

Verify the socket exists:
```bash
ls -la /var/run/docker.sock
```

### 4. Network Access

The agent must be able to reach:
- `172.20.0.26:8082` - Nexus Docker registry (internal network)
- GitHub for cloning repositories

Test connectivity:
```bash
# Test Nexus registry
curl -I http://172.20.0.26:8082/v2/

# Test Docker login (replace with actual credentials)
echo "password" | docker login 172.20.0.26:8082 -u "username" --password-stdin
```

## Woodpecker Agent Configuration

When running the Woodpecker agent, ensure it has access to Docker:

### Docker Compose Example

```yaml
services:
  woodpecker-agent:
    image: woodpeckerci/agent:latest
    environment:
      - WOODPECKER_SERVER=your-server:9000
      - WOODPECKER_SECRET=your-secret
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

### Docker Run Example

```bash
docker run -d \
  --name woodpecker-agent \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e WOODPECKER_SERVER=your-server:9000 \
  -e WOODPECKER_SECRET=your-secret \
  woodpeckerci/agent:latest
```

## Troubleshooting

### "Cannot connect to Docker daemon"

Ensure:
1. Docker is running on the host
2. The socket is mounted correctly
3. The agent has permissions to access the socket

### "HTTP response to HTTPS client"

This means the insecure-registries configuration is missing. Add `172.20.0.26:8082` to the Docker daemon's insecure-registries list and restart Docker.

### "unauthorized: authentication required"

Check:
1. Nexus credentials are correct
2. The user has push permissions to the repository
3. The repository exists in Nexus

## Security Considerations

- Mounting the Docker socket gives containers full access to the Docker daemon
- Only run trusted builds with socket access
- Consider using a dedicated agent for Docker builds
- Regularly update Docker and the agent for security patches

## Alternative: Docker-in-Docker

If socket mounting is not desired, you can use Docker-in-Docker (DinD), but this requires:
- Privileged mode (security risk)
- More complex configuration
- Potential performance overhead

The socket mount approach is recommended for better performance and simpler configuration.