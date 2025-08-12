# Docker Configuration Improvements

Based on review of official Odoo Docker setup and OpenSPP Installation Guide.

> **Note:** Configuration updated to install directly from OpenSPP APT repository instead of copying local deb files.
> 
> **Repository:** https://builds.acn.fr/repository/apt-openspp-daily/
> **Package:** `openspp-17-daily`

## Key Improvements Implemented

### APT Repository Integration (Latest Update):

1. **Direct APT Installation**
   - Removed dependency on local deb file copying
   - Docker images now pull directly from APT repository during build
   - Automatic updates to latest daily build
   - Simplified CI/CD pipeline (no deb build step needed)

2. **Repository Configuration**
   - Uses signed-by GPG key for secure APT repository
   - Supports both Ubuntu (noble) and Debian (bookworm) distributions
   - Repository URL: https://builds.acn.fr/repository/apt-openspp-daily/
   - GPG Key: https://builds.acn.fr/repository/apt-keys/openspp/public.key

3. **Benefits**
   - Always get latest daily build automatically
   - No need to manage deb files manually
   - Reduced build context size
   - Simplified build process
   - Better integration with CI/CD pipelines

### From Official Odoo Docker:

1. **Enhanced Python Dependencies**
   - Added Python packages for better compatibility: `python3-magic`, `python3-num2words`, `python3-odf`, `python3-pdfminer`, `python3-phonenumbers`, `python3-pyldap`, `python3-qrcode`, `python3-renderpm`, `python3-slugify`, `python3-vobject`, `python3-watchdog`, `python3-xlrd`, `python3-xlwt`
   - Ensures all Odoo modules work out of the box

2. **RTL Language Support**
   - Added `npm install -g rtlcss` for right-to-left language support
   - Critical for international deployments

3. **Improved Entrypoint Script**
   - Reads existing values from config file before overriding
   - Support for `PASSWORD_FILE` and `ADMIN_PASSWORD_FILE` (Docker secrets)
   - Better compatibility with legacy environment variables
   - Cleaner case statement structure matching Odoo's approach

4. **Configuration File Handling**
   - Check config file for existing parameters before environment override
   - Respect config file values when set
   - More flexible configuration management

### From OpenSPP Installation Guide:

1. **Queue Job Configuration (CRITICAL)**
   - Set default workers to 2 (was 0)
   - Added `server_wide_modules = base,web,queue_job`
   - Added `[queue_job]` section in config
   - Automatic queue_job installation on init
   - Warning messages when workers=0 in production

2. **Security Defaults**
   - Added note about `list_db = False` for production
   - Better admin password handling with generation and warnings
   - Security recommendations in documentation

3. **PostgreSQL Connection**
   - Support for Unix socket authentication (peer)
   - Better connection parameter handling
   - Improved wait-for-psql logic

4. **Memory and Performance**
   - Appropriate memory limits based on recommendations
   - Worker configuration for production vs development
   - Clear documentation about performance tuning

## Files Updated:

1. **Dockerfile**
   - Added Python dependencies and rtlcss
   - Ubuntu 24.04 LTS base (upgraded from 22.04)

2. **config/odoo.conf**
   - Workers set to 2 (minimum for queue_job)
   - Added server_wide_modules configuration
   - Added [queue_job] section

3. **docker-entrypoint.sh**
   - Complete rewrite with Odoo best practices
   - Config file reading
   - Docker secrets support
   - Queue job warnings
   - Better error handling

4. **docker-compose.yml**
   - Updated worker defaults
   - Added critical comments about queue_job

5. **README.md**
   - Added Queue Job configuration section
   - Updated feature list
   - Better production guidance

6. **Makefile** (NEW)
   - Convenient commands for Docker operations
   - Production readiness checks
   - Database initialization helpers

## Critical Requirements for OpenSPP:

### Queue Job Module
- **MUST** have workers > 0 (minimum 2 for production)
- **MUST** include queue_job in server_wide_modules
- **MUST** restart after installing queue_job module
- Development mode (workers=0) disables async operations

### Security in Production:
- Set `list_db = False`
- Use strong admin password
- Enable `proxy_mode` when behind reverse proxy
- Use Docker secrets for sensitive data

### Performance:
- Workers: 1 per CPU core (minimum 2)
- Adjust memory limits based on available RAM
- Use Redis for caching (separate container)

## Testing Checklist:

- [ ] Build standard image
- [ ] Build slim image  
- [ ] Test database initialization
- [ ] Verify queue_job installation
- [ ] Check workers configuration
- [ ] Test with docker-compose
- [ ] Verify health checks
- [ ] Test module installation
- [ ] Check logs output
- [ ] Validate production readiness

## Next Steps:

1. Run `make build-all` to build images (pulls from APT repository)
2. Run `make run` to start development environment
3. Run `make init-db` for first-time setup
4. Run `make prod-check` to validate production readiness