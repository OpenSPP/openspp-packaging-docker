#!/bin/bash
# ABOUTME: Test script for OpenSPP Docker images
# ABOUTME: Validates that built images work correctly with PostgreSQL

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGISTRY="${REGISTRY:-docker.acn.fr}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
TEST_VARIANT="${1:-ubuntu}"  # ubuntu or slim
COMPOSE_FILE="docker-compose.test.yml"

# Functions
print_header() {
    echo -e "\n${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

cleanup() {
    print_header "Cleaning up test environment"
    docker-compose -f $COMPOSE_FILE down -v 2>/dev/null || true
    print_success "Cleanup complete"
}

# Trap cleanup on exit
trap cleanup EXIT

# Parse arguments
show_usage() {
    echo "Usage: $0 [ubuntu|slim|both] [--init-db]"
    echo ""
    echo "Test OpenSPP Docker images"
    echo ""
    echo "Arguments:"
    echo "  ubuntu     Test Ubuntu-based image (default)"
    echo "  slim       Test Debian slim image"
    echo "  both       Test both variants"
    echo ""
    echo "Options:"
    echo "  --init-db  Initialize database with base modules"
    echo ""
    echo "Examples:"
    echo "  $0                    # Test Ubuntu image"
    echo "  $0 slim               # Test slim image"
    echo "  $0 both --init-db     # Test both with DB initialization"
}

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_usage
    exit 0
fi

# Check for --init-db flag
INIT_DB="false"
if [[ "$2" == "--init-db" ]] || [[ "$1" == "--init-db" ]]; then
    INIT_DB="true"
    print_info "Database initialization enabled"
fi

print_header "OpenSPP Docker Image Test"
echo "Registry: $REGISTRY"
echo "Image Tag: $IMAGE_TAG"
echo "Test Variant: $TEST_VARIANT"
echo "Initialize DB: $INIT_DB"

# Function to test a specific variant
test_variant() {
    local variant=$1
    local service_name="openspp"
    local port=8069
    
    if [[ "$variant" == "slim" ]]; then
        service_name="openspp-slim"
        port=8070
        # Temporarily modify compose file to use slim service
        sed -i.bak 's/# openspp-slim:/openspp-slim:/' $COMPOSE_FILE
        sed -i.bak '/^  openspp:$/,/^  openspp-slim:$/ s/^  openspp:$/  # openspp:/' $COMPOSE_FILE
        sed -i.bak '/^  openspp:$/,/^  # openspp-slim:$/ s/^    /  #   /' $COMPOSE_FILE
    fi
    
    print_header "Testing $variant variant"
    
    # Step 1: Pull latest image
    print_info "Pulling image..."
    local image_suffix=""
    [[ "$variant" == "slim" ]] && image_suffix="-slim"
    docker pull "$REGISTRY/openspp/openspp:${IMAGE_TAG}${image_suffix}" || {
        print_error "Failed to pull image"
        return 1
    }
    print_success "Image pulled successfully"
    
    # Step 2: Start services
    print_info "Starting services..."
    INIT_DATABASE=$INIT_DB docker-compose -f $COMPOSE_FILE up -d
    print_success "Services started"
    
    # Step 3: Wait for database
    print_info "Waiting for database..."
    for i in {1..30}; do
        if docker-compose -f $COMPOSE_FILE exec -T db pg_isready -U openspp >/dev/null 2>&1; then
            print_success "Database is ready"
            break
        fi
        [[ $i -eq 30 ]] && {
            print_error "Database failed to start"
            docker-compose -f $COMPOSE_FILE logs db
            return 1
        }
        sleep 2
    done
    
    # Step 4: Wait for OpenSPP
    print_info "Waiting for OpenSPP to start (this may take a minute)..."
    for i in {1..60}; do
        if curl -fs "http://localhost:${port}/web/health" >/dev/null 2>&1; then
            print_success "OpenSPP is running"
            break
        fi
        [[ $i -eq 60 ]] && {
            print_error "OpenSPP failed to start"
            docker-compose -f $COMPOSE_FILE logs $service_name | tail -50
            return 1
        }
        sleep 3
    done
    
    # Step 5: Test endpoints
    print_info "Testing endpoints..."
    
    # Health check
    if curl -fs "http://localhost:${port}/web/health" >/dev/null; then
        print_success "Health endpoint responding"
    else
        print_error "Health endpoint not responding"
    fi
    
    # Web interface
    response=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${port}/web")
    if [[ "$response" == "200" ]] || [[ "$response" == "303" ]]; then
        print_success "Web interface accessible (HTTP $response)"
    else
        print_error "Web interface not accessible (HTTP $response)"
    fi
    
    # Database selector (if list_db is true)
    if curl -s "http://localhost:${port}/web/database/selector" | grep -q "openspp_test"; then
        print_success "Database selector working"
    else
        print_warning "Database selector not showing test database (may need initialization)"
    fi
    
    # Step 6: Check logs for errors
    print_info "Checking logs for errors..."
    error_count=$(docker-compose -f $COMPOSE_FILE logs $service_name 2>&1 | grep -c "ERROR\|CRITICAL" || true)
    if [[ $error_count -eq 0 ]]; then
        print_success "No critical errors in logs"
    else
        print_warning "Found $error_count error messages in logs"
    fi
    
    # Step 7: Test database initialization (if requested)
    if [[ "$INIT_DB" == "true" ]]; then
        print_info "Testing database initialization..."
        docker-compose -f $COMPOSE_FILE exec -T $service_name openspp-server \
            --database=openspp_test \
            --init=base \
            --stop-after-init \
            --log-level=warn 2>&1 | grep -q "Modules loaded" && {
            print_success "Database initialization successful"
        } || {
            print_warning "Database initialization might have issues"
        }
    fi
    
    # Step 8: Performance check
    print_info "Basic performance check..."
    start_time=$(date +%s%N)
    curl -s "http://localhost:${port}" > /dev/null
    end_time=$(date +%s%N)
    response_time=$(( (end_time - start_time) / 1000000 ))
    if [[ $response_time -lt 5000 ]]; then
        print_success "Response time: ${response_time}ms"
    else
        print_warning "Response time high: ${response_time}ms"
    fi
    
    # Step 9: Container resource usage
    print_info "Container resource usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" \
        $(docker-compose -f $COMPOSE_FILE ps -q)
    
    # Cleanup for next variant
    if [[ "$variant" == "slim" ]]; then
        mv $COMPOSE_FILE.bak $COMPOSE_FILE
    fi
    
    print_success "$variant variant test completed"
    
    # Stop services before next test
    docker-compose -f $COMPOSE_FILE down
}

# Main test execution
if [[ "$TEST_VARIANT" == "both" ]]; then
    test_variant "ubuntu"
    echo ""
    test_variant "slim"
else
    test_variant "$TEST_VARIANT"
fi

print_header "Test Summary"
print_success "All tests completed"
echo ""
echo "Access OpenSPP at:"
echo "  Ubuntu: http://localhost:8069"
echo "  Slim:   http://localhost:8070"
echo ""
echo "Default credentials:"
echo "  Database: openspp_test"
echo "  Admin Password: admin"
echo ""
print_info "To keep services running, run: docker-compose -f $COMPOSE_FILE up -d"
print_info "To stop services, run: docker-compose -f $COMPOSE_FILE down"