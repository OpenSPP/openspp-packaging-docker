# ABOUTME: Production-ready OpenSPP container based on Ubuntu 24.04 LTS
# ABOUTME: Multi-stage build with security hardening and multi-arch support

# Build arguments for version control
ARG BASE_IMAGE=ubuntu:24.04

# ============================================
# Stage 1: Install OpenSPP package
# ============================================
FROM ${BASE_IMAGE} AS openspp_installer

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Install ca-certificates first, then OpenSPP package from APT repository
# Create a fake systemctl to handle postinst scripts in Docker
# Configure OpenSPP daily APT repository
RUN mkdir -p /etc/apt/keyrings \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
    && curl -fsSL https://builds.acn.fr/repository/apt-keys/openspp/public.key | \
      gpg --dearmor -o /etc/apt/keyrings/openspp.gpg \
    && gpg --show-keys /etc/apt/keyrings/openspp.gpg | grep "BE1468830EFDA9887F0BBD077A335D5FB4C1A749" \
    && echo "deb [signed-by=/etc/apt/keyrings/openspp.gpg] https://builds.acn.fr/repository/apt-openspp-daily bookworm main" > \
      /etc/apt/sources.list.d/openspp.list \
    && echo '#!/bin/sh' > /usr/bin/systemctl \
    && echo 'exit 0' >> /usr/bin/systemctl \
    && chmod +x /usr/bin/systemctl \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       openspp-17-daily \
    && rm -f /usr/bin/systemctl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/*

# ============================================
# Stage 2: Install wkhtmltopdf
# ============================================
FROM ${BASE_IMAGE} AS wkhtmltopdf_installer

ARG BASE_IMAGE=ubuntu:24.04
ARG TARGETARCH=amd64

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Install ca-certificates first, then OpenSPP package from APT repository
# Create a fake systemctl to handle postinst scripts in Docker
# Configure OpenSPP daily APT repository
WORKDIR /tmp
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
    && case "${BASE_IMAGE}" in \
    *"debian"* | *"bookworm"*) WKHTMLTOPDF_DISTRIB=bookworm && WKHTMLTOPDF_SHA=98ba0d157b50d36f23bd0dedf4c0aa28c7b0c50fcdcdc54aa5b6bbba81a3941d  ;; \
    *"ubuntu"*)  WKHTMLTOPDF_DISTRIB=jammy && WKHTMLTOPDF_SHA=4f723b2691ad8638a9df960e0421d346d7315083e3583a334f33362280ddba15  ;; \
    esac \
    && curl -o wkhtmltox.deb -sSL "https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.${WKHTMLTOPDF_DISTRIB}_${TARGETARCH}.deb" \
    && echo "${WKHTMLTOPDF_SHA}" wkhtmltox.deb | sha256sum -c - \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# Stage 3: Final production image
# ============================================
FROM ${BASE_IMAGE}

ARG BASE_IMAGE=ubuntu:24.04
ARG BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
ARG DEBIAN_FRONTEND=noninteractive
ARG GID=1001
ARG OPENSPP_LEFT_TO_RIGHT_LANGUAGE_SUPPORT=false
ARG OPENSPP_VERSION=17.0-daily
ARG PYTHONUNBUFFERED=1
ARG PYTHONDONTWRITEBYTECODE=1
ARG UID=1001
ARG VCS_REF="unspecified"

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# OCI Image Specification labels
LABEL org.opencontainers.image.title="OpenSPP" \
      org.opencontainers.image.description="OpenSPP Social Protection Platform based on Odoo 17" \
      org.opencontainers.image.version="${OPENSPP_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.authors="OpenSPP Team <support@openspp.org>" \
      org.opencontainers.image.url="https://openspp.org" \
      org.opencontainers.image.documentation="https://docs.openspp.org" \
      org.opencontainers.image.source="https://github.com/openspp/openspp-packaging-docker" \
      org.opencontainers.image.vendor="OpenSPP" \
      org.opencontainers.image.licenses="LGPL-3.0" \
      org.opencontainers.image.base.name="${BASE_IMAGE}"

# Set environment variables
# Generate locale C.UTF-8 for postgres and general locale data
# We need to set the DEBIAN_FRONTEND variable to prevent tzdata from asking us questions
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    UID=${UID} \
    GID=${GID} \
    PYTHONUNBUFFERED=${PYTHONUNBUFFERED} \
    PYTHONDONTWRITEBYTECODE=${PYTHONDONTWRITEBYTECODE} \
    ODOO_RC=/etc/openspp/odoo.conf \
    PATH="/opt/openspp/venv/bin:$PATH" \
    HOME="/var/lib/openspp"

COPY --from=wkhtmltopdf_installer /tmp/wkhtmltox.deb /tmp/wkhtmltox.deb

# Install only runtime dependencies
# Create openspp user and group with consistent IDs
# Create necessary directories with proper permissions
RUN apt-get update \
    && DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        locales \
        postgresql-client \
        python3 \
        python3-venv \
        tzdata \
        /tmp/wkhtmltox.deb \
    && if [ "${OPENSPP_LEFT_TO_RIGHT_LANGUAGE_SUPPORT}" = "true" ]; then \
        apt-get install -y --no-install-recommends \
            node-less \
            npm \
        && npm install -g rtlcss \
        && apt-get remove -y npm ; \
    fi \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 \
    && apt-get clean \
    && apt-get autopurge -yqq \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /tmp/wkhtmltox.deb \
    && bash -c "if ! getent group ${GID}; then groupadd -r -g ${GID} openspp; fi" \
    && useradd -l -u ${UID} -r -g ${GID} \
        -d /var/lib/openspp \
        -s /bin/bash \
        -m openspp \
    && mkdir -p \
        /var/lib/openspp \
        /var/log/openspp \
        /mnt/extra-addons \
        /opt/openspp/data \
    && chown -R openspp:openspp \
        /var/lib/openspp \
        /var/log/openspp \
        /mnt/extra-addons \
        /opt/openspp/data

# Copy OpenSPP installation from installer stage with correct ownership
COPY --chown=openspp:openspp --from=openspp_installer /opt/openspp /opt/openspp
COPY --from=openspp_installer /usr/bin/openspp-* /usr/bin/
COPY --chown=openspp:openspp --from=openspp_installer /etc/openspp /etc/openspp

# Copy configuration and entrypoint scripts
COPY --chown=openspp:openspp config/odoo.conf /etc/openspp/odoo.conf
COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/
COPY --chmod=755 wait-for-psql.py /usr/local/bin/

# Create volume mount points
VOLUME ["/var/lib/openspp", "/mnt/extra-addons"]

# Expose Odoo service ports
# 8069: HTTP/Web interface
# 8071: RPC interface (development)
# 8072: WebSocket/Longpolling
EXPOSE 8069 8071 8072

# Switch to non-root user
USER openspp

# Set working directory
WORKDIR /var/lib/openspp

# Health check with proper timeout and retries
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 \
    CMD curl -fs http://localhost:8069/web/health || exit 1

# Set entrypoint and default command
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["openspp-server"]
