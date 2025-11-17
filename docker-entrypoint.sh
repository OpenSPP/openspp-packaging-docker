#!/bin/bash
# ABOUTME: Docker entrypoint for OpenSPP container
# ABOUTME: Handles configuration, database wait, initialization, and proper signal handling

set -euo pipefail

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
  DB_PASSWORD="$(<"$PASSWORD_FILE")"
fi

if [ -v DB_PASSWORD_FILE ]; then
  DB_PASSWORD="$(<"$DB_PASSWORD_FILE")"
fi

if [ -v DB_USER_FILE ]; then
  DB_USER="$(<"$DB_USER_FILE")"
fi

if [ -v DB_NAME_FILE ]; then
  DB_NAME="$(<"$DB_NAME_FILE")"
fi

if [ -v ADMIN_PASSWORD_FILE ]; then
  ODOO_ADMIN_PASSWORD="$(<"$ADMIN_PASSWORD_FILE")"
fi

if [ -v ODOO_ADMIN_PASSWORD_FILE ]; then
  ODOO_ADMIN_PASSWORD="$(<"$ODOO_ADMIN_PASSWORD_FILE")"
fi

# Set default database connection parameters
# Support both new-style and legacy environment variables for compatibility
: "${DB_HOST:=${HOST:=${DB_PORT_5432_TCP_ADDR:='db'}}}"
: "${DB_PORT:=${PORT:=${DB_PORT_5432_TCP_PORT:=5432}}}"
: "${DB_USER:=${USER:=${DB_ENV_POSTGRES_USER:=${POSTGRES_USER:='openspp'}}}}"
: "${DB_PASSWORD:=${PASSWORD:=${DB_ENV_POSTGRES_PASSWORD:=${POSTGRES_PASSWORD:='openspp'}}}}"
: "${ADMIN_PASSWORD:=${ODOO_ADMIN_PASSWORD:='openspp'}}"

# Function to check if parameter exists in config file
check_config() {
  local param="$1"
  local value="$2"

  # Check if parameter exists in config file
  if grep -q -E "^\s*\b${param}\b\s*=" "$ODOO_RC" 2>/dev/null; then
    # Extract existing value from config
    local config_value
    config_value=$(grep -E "^\s*\b${param}\b\s*=" "$ODOO_RC" | cut -d "=" -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/["\n\r]//g')

    # Only use config value if it's not "false" (which means unset in Odoo config)
    if [ "${config_value}" != "false" ] && [ -n "${config_value}" ]; then
      value="${config_value}"
    fi
    # Add to arguments array
    DB_ARGS+=("--${param}")
    DB_ARGS+=("${value}")
  fi
}

# Function to wait for PostgreSQL
wait_for_postgres() {
  if [[ -n "${SKIP_DB_WAIT:-}" ]]; then
    if [[ "$SKIP_DB_WAIT" = "true" ]]; then
      log_warn "Skipping database wait (SKIP_DB_WAIT=true)"
      return 0
    fi
  fi

  log_info "Waiting for PostgreSQL at ${DB_HOST}:${DB_PORT}..."
  python3 /usr/local/bin/wait-for-psql.py
}

# Main entrypoint logic
main() {
  # Initialize arrays for Odoo arguments
  declare -a DB_ARGS=()

  # Set config file path
  ODOO_RC=${ODOO_RC:-/etc/openspp/odoo.conf}

  # Handle different command types
  case "$1" in
  -- | odoo | openspp-server)
    shift || true

    # Special case for scaffold command - doesn't need database
    if [[ -n "${1:-}" ]]; then # Check if $1 is set and not empty
      if [[ "$1" == "scaffold" ]]; then
        exec /opt/openspp/venv/bin/python /opt/openspp/odoo-bin "$@"
      fi
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

    # 1. Check for HARDCODED (uncommented) admin_passwd in the config file.
    #    This value takes precedence over environment variables.
    if grep -q -E "^\s*admin_passwd\s*=" "$ODOO_RC" 2>/dev/null; then
      log_info "Using admin_passwd from config file"
    # 2. Check if ODOO_ADMIN_PASSWORD is set in the environment.
    elif [ -n "$ODOO_ADMIN_PASSWORD" ]; then
      log_info "Using ODOO_ADMIN_PASSWORD from environment variable"
      # CRITICAL: Escape the password for safe use in sed (handles / \ &).
      SAFE_PASSWORD_ESCAPED=$(printf '%s' "$ODOO_ADMIN_PASSWORD" | sed -e 's/[\&]/\\&/g')
      DELIMITER=$(echo "$SAFE_PASSWORD_ESCAPED" | tr -d '[|:=_~]' | head -c 1)
      if [ -z "$DELIMITER" ]; then
        DELIMITER='\x01'
      fi
      # If the line is commented out, uncomment and set the ENV value.
      if grep -q "^\s*; admin_passwd\s*=" "$ODOO_RC"; then
        sed -i "s${DELIMITER}^\s*; admin_passwd\s*=.*${DELIMITER}admin_passwd = $SAFE_PASSWORD_ESCAPED${DELIMITER}g" "$ODOO_RC"      # If the admin_passwd line is missing entirely, insert it after [options].
      else
        log_info "admin_passwd line missing. Inserting ODOO_ADMIN_PASSWORD from ENV."
        sed -i "/^\[options\]/a admin_passwd = $SAFE_PASSWORD_ESCAPED" "$ODOO_RC"      fi
    # If no hardcoded or environment password is found, generate a new secure random password.
    else
      # Generate secure random password
      ODOO_ADMIN_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
      log_warn "Set ODOO_ADMIN_PASSWORD environment variable to use a specific password"
      # If the line is commented out, uncomment and set the ENV value.
      if grep -q "^\s*; admin_passwd\s*=" "$ODOO_RC"; then
        sed -i "s/^\s*; admin_passwd\s*=.*/admin_passwd = $ODOO_ADMIN_PASSWORD/g" "$ODOO_RC"
      # If the admin_passwd line is missing entirely, insert it after [options].      
      else
        log_info "admin_passwd line missing. Inserting generated password."
        sed -i "/^\[options\]/a admin_passwd = $ODOO_ADMIN_PASSWORD" "$ODOO_RC"
      fi
    fi

    # Database initialization (first run)
    if [ "${INIT_DATABASE,,}" = "true" ]; then
      log_info "Initializing database with base modules..."

      # Initialize with base module
      /opt/openspp/venv/bin/python /opt/openspp/odoo-bin \
        "${DB_ARGS[@]}" \
        --init=base \
        --stop-after-init

      log_info "Database initialization complete"

      # CRITICAL: Install queue_job module for OpenSPP
      log_info "Installing queue_job module (required for OpenSPP)..."
      /opt/openspp/venv/bin/python /opt/openspp/odoo-bin \
        "${DB_ARGS[@]}" \
        --init=queue_job \
        --stop-after-init
      log_info "queue_job module installed - restart required for job runner to start"
    fi

    # Module installation
    if [ -n "${INSTALL_MODULES}" ]; then
      log_info "Installing modules: $INSTALL_MODULES"
      /opt/openspp/venv/bin/python /opt/openspp/odoo-bin \
        "${DB_ARGS[@]}" \
        --init="$INSTALL_MODULES" \
        --stop-after-init
      log_info "Module installation complete"
    fi

    # Module updates
    if [ -n "${UPDATE_MODULES}" ]; then
      log_info "Updating modules: $UPDATE_MODULES"
      DB_ARGS+=("--update=$UPDATE_MODULES")
    fi

    # Development mode
    if [ "${ODOO_DEV_MODE,,}" = "true" ]; then
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
    DB_ARGS+=("--addons-path=${ADDONS_PATH}")

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

    # Execute OpenSPP
    # exec /opt/openspp/venv/bin/python /opt/openspp/odoo-bin "${DB_ARGS[@]}" "$@"
    exec /opt/openspp/odoo-bin "${DB_ARGS[@]}" "$@"
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
