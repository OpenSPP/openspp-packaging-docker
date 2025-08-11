# ABOUTME: Production-ready OpenSPP container based on Ubuntu 24.04 LTS
# ABOUTME: Multi-stage build with security hardening and multi-arch support

# Build arguments for version control
ARG OPENSPP_VERSION=17.0.1+odoo17.0-1
ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH=amd64

# ============================================
# Stage 1: Download and verify deb package
# ============================================
FROM ubuntu:24.04 as downloader

ARG OPENSPP_VERSION
ARG TARGETARCH
ARG DEBIAN_FRONTEND

# Install minimal tools for downloading
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

# Copy deb package from build context (provided by CI)
# The CI pipeline should provide the correct architecture deb file
COPY openspp_${OPENSPP_VERSION}_${TARGETARCH}.deb* /tmp/

# Verify package integrity if checksum provided
RUN if [ -f /tmp/openspp_${OPENSPP_VERSION}_${TARGETARCH}.deb.sha256 ]; then \
        echo "Verifying package checksum..." && \
        sha256sum -c /tmp/openspp_${OPENSPP_VERSION}_${TARGETARCH}.deb.sha256; \
    fi

# ============================================
# Stage 2: Install OpenSPP package
# ============================================
FROM ubuntu:24.04 as installer

ARG DEBIAN_FRONTEND
ARG OPENSPP_VERSION
ARG TARGETARCH

# Copy verified deb from downloader stage
COPY --from=downloader /tmp/openspp_${OPENSPP_VERSION}_${TARGETARCH}.deb /tmp/

# Install OpenSPP package and its dependencies
# The deb package should handle all dependency installation
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        /tmp/openspp_${OPENSPP_VERSION}_${TARGETARCH}.deb \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/*.deb

# ============================================
# Stage 3: Final production image
# ============================================
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND
ARG OPENSPP_VERSION
ARG BUILD_DATE
ARG VCS_REF

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
      org.opencontainers.image.base.name="ubuntu:24.04"

# Install only runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        fontconfig \
        fonts-liberation \
        fonts-noto \
        fonts-noto-cjk \
        fonts-noto-color-emoji \
        gnupg \
        gosu \
        libjs-jquery \
        libpq5 \
        libssl3 \
        locales \
        node-less \
        npm \
        postgresql-client \
        python3 \
        python3-venv \
        python3-magic \
        python3-num2words \
        python3-odf \
        python3-pdfminer \
        python3-phonenumbers \
        python3-pyldap \
        python3-qrcode \
        python3-renderpm \
        python3-slugify \
        python3-vobject \
        python3-watchdog \
        python3-xlrd \
        python3-xlwt \
        tzdata \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 \
    && npm install -g rtlcss \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set locale environment
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Copy OpenSPP installation from installer stage
COPY --from=installer /opt/openspp /opt/openspp
COPY --from=installer /usr/bin/openspp-* /usr/bin/
COPY --from=installer /etc/openspp /etc/openspp

# Create openspp user and group with consistent IDs
# Using UID/GID 1000 for better compatibility with host systems
RUN groupadd -r -g 1000 openspp && \
    useradd -r -u 1000 -g openspp \
        -d /var/lib/openspp \
        -s /bin/bash \
        -m openspp

# Create necessary directories with proper permissions
RUN mkdir -p \
        /var/lib/openspp \
        /var/log/openspp \
        /mnt/extra-addons \
        /opt/openspp/data \
    && chown -R openspp:openspp \
        /var/lib/openspp \
        /var/log/openspp \
        /mnt/extra-addons \
        /opt/openspp \
        /etc/openspp

# Copy configuration and entrypoint scripts
COPY --chown=openspp:openspp config/odoo.conf /etc/openspp/odoo.conf
COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/
COPY --chmod=755 wait-for-psql.py /usr/local/bin/

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    ODOO_RC=/etc/openspp/odoo.conf \
    PATH="/opt/openspp/venv/bin:$PATH" \
    HOME="/var/lib/openspp"

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