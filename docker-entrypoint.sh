#!/bin/bash
# ABOUTME: Docker entrypoint for OpenSPP container
# ABOUTME: Handles configuration, database wait, initialization, and proper signal handling

set -e

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Support for Docker secrets via _FILE environment variables
if [ -v PASSWORD_FILE ]; then
    DB_PASSWORD="$(< $PASSWORD_FILE)"
fi

if [ -v DB_PASSWORD_FILE ]; then
    DB_PASSWORD="$(< $DB_PASSWORD_FILE)"
fi

if [ -v DB_USER_FILE ]; then
    DB_USER="$(< $DB_USER_FILE)"
fi

if [ -v DB_NAME_FILE ]; then
    DB_NAME="$(< $DB_NAME_FILE)"
fi

if [ -v ADMIN_PASSWORD_FILE ]; then
    ODOO_ADMIN_PASSWORD="$(< $ADMIN_PASSWORD_FILE)"
fi

if [ -v ODOO_ADMIN_PASSWORD_FILE ]; then
    ODOO_ADMIN_PASSWORD="$(< $ODOO_ADMIN_PASSWORD_FILE)"
fi

# Set default database connection parameters
# Support both new-style and legacy environment variables for compatibility
: ${DB_HOST:=${HOST:=${DB_PORT_5432_TCP_ADDR:='db'}}}
: ${DB_PORT:=${PORT:=${DB_PORT_5432_TCP_PORT:=5432}}}
: ${DB_USER:=${USER:=${DB_ENV_POSTGRES_USER:=${POSTGRES_USER:='openspp'}}}}
: ${DB_PASSWORD:=${PASSWORD:=${DB_ENV_POSTGRES_PASSWORD:=${POSTGRES_PASSWORD:='openspp'}}}}

# Function to check if parameter exists in config file
check_config() {
    local param="$1"
    local value="$2"
    
    # Check if parameter exists in config file
    if grep -q -E "^\s*\b${param}\b\s*=" "$ODOO_RC" 2>/dev/null; then
        # Extract existing value from config
        local config_value=$(grep -E "^\s*\b${param}\b\s*=" "$ODOO_RC" | cut -d "=" -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/["\n\r]//g')
        
        # Only use config value if it's not "false" (which means unset in Odoo config)
        if [ "${config_value}" != "false" ] && [ -n "${config_value}" ]; then
            value="${config_value}"
            log_info "Using ${param} from config file: ${value}"
        else
            log_info "Using ${param} from environment: ${value}"
        fi
    else
        log_info "Using ${param} from environment: ${value}"
    fi
    
    # Add to arguments array
    DB_ARGS+=("--${param}")
    DB_ARGS+=("${value}")
}

# Function to wait for PostgreSQL
wait_for_postgres() {
    if [ "$SKIP_DB_WAIT" = "true" ]; then
        log_warn "Skipping database wait (SKIP_DB_WAIT=true)"
        return 0
    fi

    log_info "Waiting for PostgreSQL at ${DB_HOST}:${DB_PORT}..."
    
    # Use wait-for-psql.py if available, otherwise use psql
    if [ -f /usr/local/bin/wait-for-psql.py ]; then
        python3 /usr/local/bin/wait-for-psql.py \
            --db_host="${DB_HOST}" \
            --db_port="${DB_PORT}" \
            --db_user="${DB_USER}" \
            --db_password="${DB_PASSWORD}" \
            --timeout=30
    else
        local max_attempts=30
        local attempt=0
        
        until PGPASSWORD="${DB_PASSWORD}" psql \
            -h "${DB_HOST}" \
            -p "${DB_PORT}" \
            -U "${DB_USER}" \
            -d "postgres" \
            -c '\q' 2>/dev/null; do
            
            attempt=$((attempt + 1))
            if [ $attempt -eq $max_attempts ]; then
                log_error "PostgreSQL did not become ready in time"
                exit 1
            fi
            
            log_info "PostgreSQL is unavailable (attempt $attempt/$max_attempts) - sleeping"
            sleep 2
        done
    fi
    
    log_info "PostgreSQL is ready!"
}

# Function to handle file permissions
fix_permissions() {
    if [ "$(id -u)" = "0" ]; then
        log_info "Running as root, fixing permissions..."
        
        # Fix ownership for volumes
        chown -R openspp:openspp /var/lib/openspp || true
        chown -R openspp:openspp /mnt/extra-addons || true
        
        # Switch to openspp user using gosu
        log_info "Switching to openspp user..."
        exec gosu openspp "$0" "$@"
    fi
}

# Main entrypoint logic
main() {
    # Initialize arrays for Odoo arguments
    declare -a DB_ARGS=()
    
    # Set config file path
    ODOO_RC=${ODOO_RC:-/etc/openspp/odoo.conf}
    
    # Fix permissions if running as root
    fix_permissions "$@"
    
    # Handle different command types
    case "$1" in
        -- | odoo | openspp-server)
            shift || true
            
            # Special case for scaffold command - doesn't need database
            if [[ "$1" == "scaffold" ]]; then
                exec /opt/openspp/venv/bin/python /opt/openspp/odoo-bin "$@"
            fi
            
            # Wait for database
            wait_for_postgres
            
            # Build database arguments from config or environment
            check_config "db_host" "$DB_HOST"
            check_config "db_port" "$DB_PORT"
            check_config "db_user" "$DB_USER"
            check_config "db_password" "$DB_PASSWORD"
            
            # Set database name if specified
            if [ -n "${DB_NAME}" ] && [ "${DB_NAME}" != "false" ]; then
                DB_ARGS+=("--database=${DB_NAME}")
            fi
            
            # Admin password handling
            if [ -z "$ODOO_ADMIN_PASSWORD" ]; then
                # Check if admin_passwd is set in config
                if grep -q -E "^\s*admin_passwd\s*=" "$ODOO_RC" 2>/dev/null; then
                    log_info "Using admin_passwd from config file"
                else
                    # Generate secure random password if not set
                    ODOO_ADMIN_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
                    log_warn "Generated random admin password: $ODOO_ADMIN_PASSWORD"
                    log_warn "Set ODOO_ADMIN_PASSWORD environment variable to use a specific password"
                    DB_ARGS+=("--admin_passwd=${ODOO_ADMIN_PASSWORD}")
                fi
            else
                DB_ARGS+=("--admin_passwd=${ODOO_ADMIN_PASSWORD}")
            fi
            
            # Add optional parameters from environment
            [ -n "$ODOO_LIST_DB" ] && DB_ARGS+=("--list_db=${ODOO_LIST_DB}")
            [ -n "$ODOO_LOG_LEVEL" ] && DB_ARGS+=("--log_level=${ODOO_LOG_LEVEL}")
            [ -n "$ODOO_WORKERS" ] && DB_ARGS+=("--workers=${ODOO_WORKERS}")
            [ -n "$ODOO_MAX_CRON_THREADS" ] && DB_ARGS+=("--max_cron_threads=${ODOO_MAX_CRON_THREADS}")
            [ -n "$ODOO_PROXY_MODE" ] && DB_ARGS+=("--proxy_mode=${ODOO_PROXY_MODE}")
            [ -n "$ODOO_WITHOUT_DEMO" ] && DB_ARGS+=("--without-demo=all")
            
            # Database initialization (first run)
            if [ "$INIT_DATABASE" = "true" ]; then
                log_info "Initializing database with base modules..."
                
                # Create database if it doesn't exist
                if [ -n "${DB_NAME}" ]; then
                    PGPASSWORD="${DB_PASSWORD}" createdb \
                        -h "${DB_HOST}" \
                        -p "${DB_PORT}" \
                        -U "${DB_USER}" \
                        "${DB_NAME}" 2>/dev/null || true
                fi
                
                # Initialize with base module
                /opt/openspp/venv/bin/python /opt/openspp/odoo-bin \
                    "${DB_ARGS[@]}" \
                    --init=base \
                    --stop-after-init
                
                log_info "Database initialization complete"
                
                # CRITICAL: Install queue_job module for OpenSPP
                if [ "$INSTALL_QUEUE_JOB" != "false" ]; then
                    log_info "Installing queue_job module (required for OpenSPP)..."
                    /opt/openspp/venv/bin/python /opt/openspp/odoo-bin \
                        "${DB_ARGS[@]}" \
                        --init=queue_job \
                        --stop-after-init
                    log_info "queue_job module installed - restart required for job runner to start"
                fi
            fi
            
            # Module installation
            if [ -n "$INSTALL_MODULES" ]; then
                log_info "Installing modules: $INSTALL_MODULES"
                /opt/openspp/venv/bin/python /opt/openspp/odoo-bin \
                    "${DB_ARGS[@]}" \
                    --init="$INSTALL_MODULES" \
                    --stop-after-init
                log_info "Module installation complete"
            fi
            
            # Module updates
            if [ -n "$UPDATE_MODULES" ]; then
                log_info "Updating modules: $UPDATE_MODULES"
                DB_ARGS+=("--update=$UPDATE_MODULES")
            fi
            
            # Development mode
            if [ "$ODOO_DEV_MODE" = "true" ]; then
                log_warn "Enabling development mode..."
                DB_ARGS+=("--dev=all")
                # Override workers for development
                DB_ARGS+=("--workers=0")
                log_warn "Workers set to 0 for development mode - queue_job will NOT function!"
            fi
            
            # Handle addons path
            ADDONS_PATH="/opt/openspp/addons"
            if [ -d "/mnt/extra-addons" ] && [ "$(ls -A /mnt/extra-addons 2>/dev/null)" ]; then
                ADDONS_PATH="${ADDONS_PATH},/mnt/extra-addons"
                log_info "Extra addons detected at /mnt/extra-addons"
            fi
            DB_ARGS+=("--addons_path=${ADDONS_PATH}")
            
            # Log to stdout for container logs
            DB_ARGS+=("--logfile=-")
            
            # Check workers configuration for queue_job
            WORKERS_COUNT=$(echo "${ODOO_WORKERS:-2}" | grep -o '[0-9]*')
            if [ "$WORKERS_COUNT" -eq 0 ] && [ "$ODOO_DEV_MODE" != "true" ]; then
                log_warn "================================================"
                log_warn "WARNING: workers=0 detected in production mode!"
                log_warn "Queue Job async processing will NOT work!"
                log_warn "Set ODOO_WORKERS to at least 2 for production"
                log_warn "================================================"
            fi
            
            log_info "Starting OpenSPP server..."
            # Note: Database credentials may be visible in process list when passed as arguments
            # This is a known limitation when using command-line arguments
            # Consider using mounted config files for highly sensitive environments
            log_info "Command: odoo-bin ${DB_ARGS[*]} $*"
            
            # Execute OpenSPP
            exec /opt/openspp/venv/bin/python /opt/openspp/odoo-bin "${DB_ARGS[@]}" "$@"
            ;;
            
        -*)
            # Odoo command with flags
            wait_for_postgres
            
            # Build database arguments
            check_config "db_host" "$DB_HOST"
            check_config "db_port" "$DB_PORT"
            check_config "db_user" "$DB_USER"
            check_config "db_password" "$DB_PASSWORD"
            
            exec /opt/openspp/venv/bin/python /opt/openspp/odoo-bin "$@" "${DB_ARGS[@]}"
            ;;
            
        *)
            # Custom command - execute directly
            exec "$@"
            ;;
    esac
}

# Run main function
main "$@"