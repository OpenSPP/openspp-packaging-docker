# Testing OpenSPP Docker Images

This guide provides instructions for testing OpenSPP Docker images after they're built.

## Quick Start

### Automated Testing

Use the provided test script for comprehensive testing:

```bash
# Make script executable
chmod +x test-images.sh

# Test Ubuntu image (default)
./test-images.sh

# Test slim image
./test-images.sh slim

# Test both variants
./test-images.sh both

# Test with database initialization
./test-images.sh ubuntu --init-db
```

### Manual Testing with Docker Compose

1. **Test the latest images from registry:**
```bash
# Start services
docker-compose -f docker-compose.test.yml up -d

# Watch logs
docker-compose -f docker-compose.test.yml logs -f

# Access OpenSPP
open http://localhost:8069

# Stop services
docker-compose -f docker-compose.test.yml down -v
```

2. **Test specific image tags:**
```bash
# Test weekly build
IMAGE_TAG=weekly docker-compose -f docker-compose.test.yml up -d

# Test specific version
IMAGE_TAG=v1.0.0 docker-compose -f docker-compose.test.yml up -d

# Test slim variant
IMAGE_TAG=latest-slim docker-compose -f docker-compose.test.yml up -d
```

3. **Test with database initialization:**
```bash
INIT_DATABASE=true docker-compose -f docker-compose.test.yml up -d
```

## Test Scenarios

### 1. Basic Functionality Test
- ✅ Image pulls successfully
- ✅ Container starts without errors
- ✅ Health endpoint responds
- ✅ Web interface is accessible
- ✅ Can connect to PostgreSQL

### 2. Database Operations Test
```bash
# Initialize database with modules
docker-compose -f docker-compose.test.yml exec openspp \
  openspp-server --database=openspp_test --init=base,web --stop-after-init

# Test database connection
docker-compose -f docker-compose.test.yml exec openspp \
  openspp-shell --database=openspp_test -c "print('Connected')"
```

### 3. Performance Test
```bash
# Check response time
time curl -s http://localhost:8069 > /dev/null

# Monitor resource usage
docker stats openspp-test-app

# Load test (requires apache2-utils)
ab -n 100 -c 10 http://localhost:8069/
```

### 4. Module Installation Test
```bash
# Install OpenSPP modules
docker-compose -f docker-compose.test.yml exec openspp \
  openspp-server --database=openspp_test \
  --init=spp_base,g2p_registry_base \
  --stop-after-init
```

### 5. Multi-Architecture Test
```bash
# Test on different architectures (if available)
docker run --rm --platform linux/amd64 \
  docker.acn.fr/openspp/openspp:latest \
  openspp-server --version
```

## Validation Checklist

### Image Build Validation
- [ ] Image size is reasonable (~1.5GB for Ubuntu, ~1.0GB for slim)
- [ ] No security vulnerabilities in base image
- [ ] All required files are present
- [ ] Proper user permissions (non-root)

### Runtime Validation
- [ ] Container starts successfully
- [ ] No critical errors in logs
- [ ] Health check passes
- [ ] Web interface loads
- [ ] Database connection works
- [ ] Queue jobs run (with workers > 0)
- [ ] Custom addons can be loaded

### Security Validation
- [ ] Running as non-root user (openspp)
- [ ] No exposed secrets in environment
- [ ] Proper file permissions
- [ ] Network isolation works

## Debugging Failed Tests

### Container Won't Start
```bash
# Check logs
docker-compose -f docker-compose.test.yml logs openspp

# Check detailed error
docker-compose -f docker-compose.test.yml up openspp

# Shell into container
docker-compose -f docker-compose.test.yml run openspp /bin/bash
```

### Database Connection Issues
```bash
# Test database connectivity
docker-compose -f docker-compose.test.yml exec openspp \
  pg_isready -h db -U openspp

# Check database logs
docker-compose -f docker-compose.test.yml logs db
```

### Module Import Errors
```bash
# Check Python environment
docker-compose -f docker-compose.test.yml exec openspp \
  python3 -c "import odoo; print(odoo.__version__)"

# List available modules
docker-compose -f docker-compose.test.yml exec openspp \
  openspp-server --database=openspp_test --list-modules
```

## Test Different Registry

To test images from a different registry:

```bash
# Test from Docker Hub
REGISTRY=docker.io docker-compose -f docker-compose.test.yml up -d

# Test from local registry
REGISTRY=localhost:5000 docker-compose -f docker-compose.test.yml up -d
```

## Automated CI Testing

The GitHub Actions workflow automatically tests images on:
- Pull requests
- Weekly scheduled builds
- Manual workflow dispatches

To manually trigger tests:
1. Go to [Actions](https://github.com/OpenSPP/openspp-packaging-docker/actions)
2. Select "Docker Build and Push"
3. Click "Run workflow"
4. Select branch and options

## Clean Up

After testing:

```bash
# Stop and remove containers
docker-compose -f docker-compose.test.yml down

# Remove volumes
docker-compose -f docker-compose.test.yml down -v

# Remove test images
docker rmi $(docker images | grep openspp | awk '{print $3}')

# Full cleanup
./test-images.sh clean
```

## Reporting Issues

If tests fail:
1. Capture the error logs
2. Note the image tag and registry
3. Document the test scenario
4. Report at [GitHub Issues](https://github.com/OpenSPP/openspp-packaging-docker/issues)