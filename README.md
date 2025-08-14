# OpenSPP Docker Packaging

Production-ready Docker images for OpenSPP Social Protection Platform based on Odoo 17.

> **Note:** This configuration uses OpenSPP daily builds from the [apt-openspp-daily](https://builds.acn.fr/repository/apt-openspp-daily/) repository. The package name is `openspp-17-daily`.

## Docker Registry

Images are hosted on ACN Nexus Docker Registry:
- **Public access (pull):** `docker.acn.fr/openspp/openspp`
- **Push access:** `docker-push.acn.fr/openspp/openspp` (requires authentication)

## Features

- 🚀 **Multi-architecture support** (amd64, arm64)
- 🔒 **Security-hardened** with non-root user and minimal attack surface
- 📦 **Two image variants**: Ubuntu 24.04 LTS (standard) and Debian slim (lightweight)
- ⚡ **Optimized builds** with multi-stage Dockerfile
- 🔧 **Flexible configuration** via environment variables
- 📊 **Production-ready** with health checks and proper signal handling
- 🤖 **CI/CD integration** with Woodpecker
- 🔄 **Queue Job support** for OpenSPP async operations
- 🌍 **RTL support** with rtlcss for right-to-left languages

## Quick Start

### Using Docker Compose (Development)

1. Clone this repository:
```bash
git clone https://github.com/openspp/openspp-packaging-docker.git
cd openspp-packaging-docker
```

2. Build and start the services:
```bash
# Build the image (pulls from APT repository)
docker-compose build

# Start the services
docker-compose up -d
```

3. Initialize the database (first run only):
```bash
docker-compose exec openspp env INIT_DATABASE=true openspp-server
```

4. Access OpenSPP at http://localhost:8069

Default credentials:
- Username: admin
- Password: admin

### Using Docker Run

```bash
# Start PostgreSQL
docker run -d \
  --name openspp-db \
  -e POSTGRES_USER=openspp \
  -e POSTGRES_PASSWORD=openspp \
  -e POSTGRES_DB=openspp \
  postgres:15-alpine

# Start OpenSPP
docker run -d \
  --name openspp \
  --link openspp-db:db \
  -p 8069:8069 \
  -e DB_HOST=db \
  -e DB_USER=openspp \
  -e DB_PASSWORD=openspp \
  -e DB_NAME=openspp \
  -e DB_PORT=5432 \
  -e ODOO_ADMIN_PASSWORD=admin \
  docker.acn.fr/openspp/openspp:latest
```

## Image Variants

### Standard Image (Ubuntu 24.04 LTS)
- **Base**: Ubuntu 24.04 LTS
- **Size**: ~1.5GB
- **Use case**: Production deployments requiring maximum compatibility
- **Tag**: `docker.acn.fr/openspp/openspp:latest`

### Slim Image (Debian Bookworm)
- **Base**: Debian bookworm-slim
- **Size**: ~1.0GB
- **Use case**: Resource-constrained environments
- **Tag**: `docker.acn.fr/openspp/openspp:latest-slim`

## Configuration

### Environment Variables

#### Database Configuration
| Variable | Default | Description |
|----------|---------|-------------|
| `DB_HOST` | `db` | PostgreSQL host |
| `DB_PORT` | `5432` | PostgreSQL port |
| `DB_USER` | `openspp` | Database user |
| `DB_PASSWORD` | `openspp` | Database password |
| `DB_NAME` | `openspp` | Database name |

#### Odoo Configuration
| Variable | Default | Description |
|----------|---------|-------------|
| `ODOO_ADMIN_PASSWORD` | random | Master admin password |
| `ODOO_LIST_DB` | `True` | Show database selector (set to `False` in production) |
| `ODOO_LOG_LEVEL` | `info` | Log level (debug/info/warn/error) |
| `ODOO_WORKERS` | `2` | Number of workers (MUST be ≥2 for queue_job) |
| `ODOO_PROXY_MODE` | `False` | Enable proxy mode |

#### Initialization
| Variable | Default | Description |
|----------|---------|-------------|
| `INIT_DATABASE` | `false` | Initialize database on startup |
| `INSTALL_MODULES` | - | Comma-separated modules to install |
| `UPDATE_MODULES` | - | Comma-separated modules to update |
| `ODOO_DEV_MODE` | `false` | Enable development mode |
| `ODOO_WITHOUT_DEMO` | `false` | Disable demo data |

### Volumes

| Path | Description |
|------|-------------|
| `/var/lib/openspp` | Persistent data (filestore) |
| `/mnt/extra-addons` | Custom addon modules |

### Ports

| Port | Description |
|------|-------------|
| `8069` | HTTP/Web interface |
| `8071` | RPC interface (development) |
| `8072` | WebSocket/Longpolling |

## Important: Queue Job Configuration

OpenSPP requires the `queue_job` module for asynchronous operations. **This is CRITICAL for proper functioning.**

### Requirements:
1. **Workers MUST be > 0** (minimum 2 for production)
   - Set `ODOO_WORKERS=2` or higher
   - Development mode (`ODOO_DEV_MODE=true`) sets workers to 0, disabling queue_job
2. **Module Installation**:
   - The `queue_job` module is automatically configured in `server_wide_modules`
   - On first run with `INIT_DATABASE=true`, queue_job is installed automatically
   - **Restart required** after installing queue_job for the job runner to start

### Verification:
Check if queue jobs are running:
```bash
# Check workers configuration
docker exec openspp grep workers /etc/openspp/odoo.conf

# Monitor jobs in Odoo
# Navigate to Settings > Technical > Queue Job > Jobs
```

## Production Deployment

### Using Docker Compose

1. Create Docker secrets:
```bash
echo "openspp" | docker secret create db_name -
echo "openspp" | docker secret create db_user -
echo "strong_password" | docker secret create db_password -
echo "admin_password" | docker secret create admin_password -
echo "redis_password" | docker secret create redis_password -
```

2. Deploy with production configuration:
```bash
docker-compose -f docker-compose.prod.yml up -d
```

### Kubernetes Deployment

See [kubernetes/](./kubernetes/) directory for Helm charts and manifests.

### Security Considerations

1. **Always use secrets** for sensitive data (passwords, API keys)
2. **Enable proxy mode** when behind a reverse proxy
3. **Restrict database access** to OpenSPP containers only
4. **Use SSL/TLS** for external access
5. **Regular security updates** of base images
6. **Implement network policies** in Kubernetes

## Building Images

### Local Build

```bash
# Build standard image (installs from APT repository)
make build

# Build slim image (installs from APT repository)
make build-slim

# Build both images
make build-all

# Build for multiple architectures
docker buildx build --platform linux/amd64,linux/arm64 -t openspp:local .
```

Note: The images automatically install the latest daily build from the OpenSPP APT repository at https://builds.acn.fr/repository/apt-openspp-daily/

### Pushing to Nexus Registry

```bash
# Login to Nexus registry
make login
# Or manually:
docker login docker-push.acn.fr

# Push images
make push
```

Images will be available at:
- `docker.acn.fr/openspp/openspp:latest` (public access)
- `docker.acn.fr/openspp/openspp:latest-slim` (public access)

### CI/CD Pipeline

The Woodpecker CI pipeline automatically:
1. Creates multi-arch Docker images (pulling from APT repository)
2. Runs security scans with Trivy
3. Tests the images
4. Pushes to registry on tags

## Monitoring

### Health Check

The container includes a health check endpoint:
```bash
curl http://localhost:8069/web/health
```

### Logs

View container logs:
```bash
docker logs -f openspp
```

### Metrics

For production monitoring, consider:
- Prometheus + Grafana for metrics
- ELK/EFK stack for log aggregation
- APM tools like New Relic or DataDog

## Troubleshooting

### Database Connection Issues
```bash
# Check database connectivity
docker exec openspp pg_isready -h db -U openspp

# View connection logs
docker logs openspp | grep -i database
```

### Permission Issues
```bash
# Fix volume permissions
docker exec -u root openspp chown -R openspp:openspp /var/lib/openspp
```

### Module Installation
```bash
# Install modules manually
docker exec openspp env UPDATE_MODULES=base,web openspp-server
```

## Development

### Custom Addons

1. Place addons in `custom-addons/` directory
2. Restart container to detect new modules:
```bash
docker-compose restart openspp
```

### Debugging

Enable development mode:
```bash
docker-compose exec openspp env ODOO_DEV_MODE=true openspp-server
```

## License

LGPL-3.0 - See [LICENSE](LICENSE) file for details.

## Support

- Documentation: https://docs.openspp.org
- Issues: https://github.com/openspp/openspp-packaging-docker/issues
- Community: https://community.openspp.org
- APT Repository (Daily): https://builds.acn.fr/repository/apt-openspp-daily/

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.
