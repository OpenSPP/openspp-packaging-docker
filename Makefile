# ABOUTME: Makefile for OpenSPP Docker operations
# ABOUTME: Provides convenient commands for building, running, and managing OpenSPP containers

.PHONY: help build build-slim build-all run stop clean logs shell db-shell test push

# Variables
IMAGE_TAG ?= daily
REGISTRY ?= docker.acn.fr
PUSH_REGISTRY ?= docker-push.acn.fr
REPO ?= openspp/openspp
IMAGE_NAME = $(REGISTRY)/$(REPO)
PUSH_IMAGE_NAME = $(PUSH_REGISTRY)/$(REPO)
COMPOSE_FILE ?= docker-compose.yml
COMPOSE_PROD_FILE ?= docker-compose.prod.yml

# Colors for output
RED := \033[1;31m
GREEN := \033[1;32m
YELLOW := \033[1;33m
NC := \033[0m # No Color

help: ## Show this help message
	@echo -e "$(GREEN)OpenSPP Docker Management$(NC)"
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}'

build: ## Build the standard Ubuntu-based image
	@echo -e "$(GREEN)Building OpenSPP image (Ubuntu 24.04)...$(NC)"
	@echo -e "$(YELLOW)Installing from APT repository: https://builds.acn.fr/repository/apt-openspp-daily$(NC)"
	docker build \
		--build-arg BUILD_DATE=$(shell date -u +'%Y-%m-%dT%H:%M:%SZ') \
		--build-arg VCS_REF=$(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown") \
		-t $(IMAGE_NAME):$(IMAGE_TAG) \
		-t $(IMAGE_NAME):latest \
		-t $(PUSH_IMAGE_NAME):$(IMAGE_TAG) \
		-t $(PUSH_IMAGE_NAME):latest \
		-f Dockerfile .

build-slim: ## Build the lightweight Debian-based image
	@echo -e "$(GREEN)Building OpenSPP slim image (Debian bookworm)...$(NC)"
	@echo -e "$(YELLOW)Installing from APT repository: https://builds.acn.fr/repository/apt-openspp-daily$(NC)"
	docker build \
		--build-arg BUILD_DATE=$(shell date -u +'%Y-%m-%dT%H:%M:%SZ') \
		--build-arg VCS_REF=$(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown") \
		-t $(IMAGE_NAME):$(IMAGE_TAG)-slim \
		-t $(IMAGE_NAME):latest-slim \
		-t $(PUSH_IMAGE_NAME):$(IMAGE_TAG)-slim \
		-t $(PUSH_IMAGE_NAME):latest-slim \
		-f Dockerfile.slim .

build-all: build build-slim ## Build both standard and slim images

run: ## Start OpenSPP with docker-compose (development)
	@echo -e "$(GREEN)Starting OpenSPP development environment...$(NC)"
	docker-compose -f $(COMPOSE_FILE) up -d
	@echo -e "$(GREEN)OpenSPP is starting at http://localhost:8069$(NC)"
	@echo -e "$(YELLOW)Note: Workers are set to 2 for queue_job support$(NC)"

run-prod: ## Start OpenSPP with production configuration
	@echo -e "$(GREEN)Starting OpenSPP production environment...$(NC)"
	docker-compose -f $(COMPOSE_PROD_FILE) up -d
	@echo -e "$(GREEN)OpenSPP production is starting$(NC)"

stop: ## Stop all OpenSPP containers
	@echo -e "$(YELLOW)Stopping OpenSPP containers...$(NC)"
	docker-compose -f $(COMPOSE_FILE) down

stop-prod: ## Stop production containers
	@echo -e "$(YELLOW)Stopping OpenSPP production containers...$(NC)"
	docker-compose -f $(COMPOSE_PROD_FILE) down

clean: ## Remove containers, volumes, and images
	@echo -e "$(RED)Removing OpenSPP containers and volumes...$(NC)"
	docker-compose -f $(COMPOSE_FILE) down -v
	@echo -e "$(RED)Removing OpenSPP images...$(NC)"
	docker rmi $(IMAGE_NAME):$(IMAGE_TAG) $(IMAGE_NAME):latest || true
	docker rmi $(IMAGE_NAME):$(IMAGE_TAG)-slim $(IMAGE_NAME):latest-slim || true

logs: ## View OpenSPP container logs
	docker-compose -f $(COMPOSE_FILE) logs -f openspp

logs-all: ## View all container logs
	docker-compose -f $(COMPOSE_FILE) logs -f

shell: ## Open a shell in the OpenSPP container
	@echo -e "$(GREEN)Opening shell in OpenSPP container...$(NC)"
	docker-compose -f $(COMPOSE_FILE) exec openspp /bin/bash

shell-root: ## Open a root shell in the OpenSPP container
	@echo -e "$(GREEN)Opening root shell in OpenSPP container...$(NC)"
	docker-compose -f $(COMPOSE_FILE) exec -u root openspp /bin/bash

db-shell: ## Open PostgreSQL shell
	@echo -e "$(GREEN)Opening PostgreSQL shell...$(NC)"
	docker-compose -f $(COMPOSE_FILE) exec db psql -U openspp openspp

odoo-shell: ## Open Odoo Python shell
	@echo -e "$(GREEN)Opening Odoo Python shell...$(NC)"
	docker-compose -f $(COMPOSE_FILE) exec openspp openspp-shell

test: ## Run basic tests on the container
	@echo -e "$(GREEN)Running container tests...$(NC)"
	@echo "1. Testing image build..."
	docker run --rm $(IMAGE_NAME):latest openspp-server --version
	@echo -e "$(GREEN)✓ Version check passed$(NC)"
	@echo ""
	@echo "2. Testing health endpoint..."
	docker-compose -f $(COMPOSE_FILE) up -d
	@sleep 30
	@curl -f http://localhost:8069/web/health && echo "$(GREEN)✓ Health check passed$(NC)" || echo "$(RED)✗ Health check failed$(NC)"
	@echo ""
	@echo "3. Checking workers configuration..."
	@docker-compose -f $(COMPOSE_FILE) exec openspp grep "workers" /etc/openspp/odoo.conf
	@echo -e "$(GREEN)✓ Workers configuration checked$(NC)"

init-db: ## Initialize database with base modules
	@echo -e "$(GREEN)Initializing OpenSPP database...$(NC)"
	docker-compose -f $(COMPOSE_FILE) run --rm \
		-e INIT_DATABASE=true \
		-e INSTALL_QUEUE_JOB=true \
		openspp
	@echo -e "$(GREEN)Database initialized. Restart required for queue_job.$(NC)"
	@echo "Run: make restart"

restart: ## Restart OpenSPP containers
	@echo -e "$(YELLOW)Restarting OpenSPP containers...$(NC)"
	docker-compose -f $(COMPOSE_FILE) restart
	@echo -e "$(GREEN)OpenSPP restarted$(NC)"

install-modules: ## Install OpenSPP modules (set MODULES env var)
	@echo -e "$(GREEN)Installing modules: $(MODULES)$(NC)"
	docker-compose -f $(COMPOSE_FILE) run --rm \
		-e INSTALL_MODULES="$(MODULES)" \
		openspp
	@echo -e "$(GREEN)Modules installed$(NC)"

update-modules: ## Update OpenSPP modules (set MODULES env var)
	@echo -e "$(GREEN)Updating modules: $(MODULES)$(NC)"
	docker-compose -f $(COMPOSE_FILE) run --rm \
		-e UPDATE_MODULES="$(MODULES)" \
		openspp
	@echo -e "$(GREEN)Modules updated$(NC)"

backup: ## Backup database and filestore
	@echo -e "$(GREEN)Creating backup...$(NC)"
	@mkdir -p backups
	@docker-compose -f $(COMPOSE_FILE) exec db pg_dump -U openspp openspp | gzip > backups/openspp_$(shell date +%Y%m%d_%H%M%S).sql.gz
	@docker-compose -f $(COMPOSE_FILE) exec openspp tar -czf - /var/lib/openspp > backups/filestore_$(shell date +%Y%m%d_%H%M%S).tar.gz
	@echo -e "$(GREEN)Backup completed in ./backups/$(NC)"

push: ## Push images to Nexus registry
	@echo -e "$(GREEN)Pushing images to $(PUSH_REGISTRY)...$(NC)"
	@echo -e "$(YELLOW)Note: Make sure you're logged in: docker login $(PUSH_REGISTRY)$(NC)"
	docker push $(PUSH_IMAGE_NAME):$(IMAGE_TAG)
	docker push $(PUSH_IMAGE_NAME):latest
	docker push $(PUSH_IMAGE_NAME):$(IMAGE_TAG)-slim
	docker push $(PUSH_IMAGE_NAME):latest-slim
	@echo -e "$(GREEN)Images pushed successfully$(NC)"
	@echo -e "$(GREEN)Images available for public access at:$(NC)"
	@echo "  $(IMAGE_NAME):$(IMAGE_TAG)"
	@echo "  $(IMAGE_NAME):$(IMAGE_TAG)-slim"

scan: ## Security scan with Trivy
	@echo -e "$(GREEN)Scanning images for vulnerabilities...$(NC)"
	@which trivy > /dev/null || (echo "$(RED)Trivy not installed. Install from: https://github.com/aquasecurity/trivy$(NC)" && exit 1)
	trivy image --severity HIGH,CRITICAL $(IMAGE_NAME):latest
	trivy image --severity HIGH,CRITICAL $(IMAGE_NAME):latest-slim

info: ## Show environment information
	@echo -e "$(GREEN)OpenSPP Docker Environment Information$(NC)"
	@echo "Image Tag: $(IMAGE_TAG)"
	@echo "Public Registry: $(REGISTRY)"
	@echo "Push Registry: $(PUSH_REGISTRY)"
	@echo "Repository: $(REPO)"
	@echo "Public Image: $(IMAGE_NAME)"
	@echo "Push Image: $(PUSH_IMAGE_NAME)"
	@echo "APT Repository: https://builds.acn.fr/repository/apt-openspp-daily"
	@echo ""
	@echo -e "$(YELLOW)Container Status:$(NC)"
	@docker-compose -f $(COMPOSE_FILE) ps
	@echo ""
	@echo -e "$(YELLOW)Image Information:$(NC)"
	@docker images | grep openspp || echo "No OpenSPP images found"

# Development helpers
dev: ## Start in development mode (workers=0, dev mode enabled)
	@echo -e "$(YELLOW)Starting in development mode (queue_job disabled)...$(NC)"
	ODOO_DEV_MODE=true WORKERS=0 docker-compose -f $(COMPOSE_FILE) up -d
	@echo -e "$(GREEN)Development mode started at http://localhost:8069$(NC)"
	@echo -e "$(YELLOW)Warning: Queue jobs are disabled in dev mode$(NC)"

prod-check: ## Validate production readiness
	@echo -e "$(GREEN)Checking production readiness...$(NC)"
	@echo -n "1. Checking workers configuration... "
	@docker-compose -f $(COMPOSE_FILE) exec openspp grep "workers" /etc/openspp/odoo.conf | grep -q "workers = [2-9]" && echo "$(GREEN)✓$(NC)" || echo "$(RED)✗ Workers < 2$(NC)"
	@echo -n "2. Checking queue_job in server_wide_modules... "
	@docker-compose -f $(COMPOSE_FILE) exec openspp grep "server_wide_modules" /etc/openspp/odoo.conf | grep -q "queue_job" && echo "$(GREEN)✓$(NC)" || echo "$(RED)✗ Missing queue_job$(NC)"
	@echo -n "3. Checking list_db setting... "
	@docker-compose -f $(COMPOSE_FILE) exec openspp grep "list_db" /etc/openspp/odoo.conf | grep -q "False" && echo "$(GREEN)✓$(NC)" || echo "$(YELLOW)⚠ list_db=True (should be False for production)$(NC)"
	@echo -n "4. Checking admin password... "
	@docker-compose -f $(COMPOSE_FILE) exec openspp grep "admin_passwd" /etc/openspp/odoo.conf | grep -q "admin_passwd = admin" && echo "$(RED)✗ Using default password$(NC)" || echo "$(GREEN)✓$(NC)"
	@echo ""
	@echo -e "$(GREEN)Production check complete$(NC)"

login: ## Login to Nexus Docker registry
	@echo -e "$(GREEN)Logging in to Nexus registry: $(PUSH_REGISTRY)$(NC)"
	@docker login $(PUSH_REGISTRY)
	@echo -e "$(GREEN)Successfully logged in to $(PUSH_REGISTRY)$(NC)"
