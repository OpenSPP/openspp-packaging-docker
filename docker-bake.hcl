group "default" {
  targets = [
    "openspp-debian-bookworm-slim",
    "openspp-debian-trixie-slim",
    "openspp-ubuntu-24-04",
    "openspp-python-3-14-slim-bookworm",
    "openspp-python-3-13-slim-bookworm",
    "openspp-python-3-12-slim-bookworm"
  ]
}

target "common" {
  args = {
    BUILD_DATE              = "$(date -u +\"%Y-%m-%dT%H:%M:%SZ\")"
    DEBIAN_FRONTEND         = "noninteractive"
    GID                     = "1001"
    PYTHONUNBUFFERED        = "1"
    PYTHONDONTWRITEBYTECODE = "1"
    UID                     = "1001"
    VCS_REF                 = "master"
  }
}

target "openspp-debian-bookworm-slim" {
  inherits   = ["common"]
  context    = "."
  dockerfile = "Dockerfile"
  tags = ["openspp:debian-bookworm-slim"]
  args = {
    BASE_IMAGE      = "debian:bookworm-slim"
    OPENSPP_VERSION = "17.0.1-daily+odoo17.0-1"
  }
  platforms = ["linux/amd64"]
}

target "openspp-debian-trixie-slim" {
  inherits   = ["common"]
  context    = "."
  dockerfile = "Dockerfile"
  tags = ["openspp:debian-trixie-slim"]
  args = {
    BASE_IMAGE      = "debian:trixie-slim"
    OPENSPP_VERSION = "17.0.1-daily+odoo17.0-1"
  }
  platforms = ["linux/amd64"]
}

target "openspp-ubuntu-24-04" {
  inherits   = ["common"]
  context    = "."
  dockerfile = "Dockerfile"
  tags = ["openspp:ubuntu-24.04"]
  args = {
    BASE_IMAGE      = "ubuntu:24.04"
    OPENSPP_VERSION = "17.0.1-daily+odoo17.0-1"
  }
  platforms = ["linux/amd64"]
}

target "openspp-python-3-14-slim-bookworm" {
  inherits   = ["common"]
  context    = "."
  dockerfile = "Dockerfile"
  tags = ["openspp:python-3-14-slim-bookworm"]
  args = {
    BASE_IMAGE      = "python:3.14-slim-bookworm"
    OPENSPP_VERSION = "17.0.1-daily+odoo17.0-1"
  }
  platforms = ["linux/amd64"]
}

target "openspp-python-3-13-slim-bookworm" {
  inherits   = ["common"]
  context    = "."
  dockerfile = "Dockerfile"
  tags = ["openspp:python-3-13-slim-bookworm"]
  args = {
    BASE_IMAGE      = "python:3.13-slim-bookworm"
    OPENSPP_VERSION = "17.0.1-daily+odoo17.0-1"
  }
  platforms = ["linux/amd64"]
}

target "openspp-python-3-12-slim-bookworm" {
  inherits   = ["common"]
  context    = "."
  dockerfile = "Dockerfile"
  tags = ["openspp:python-3-12-slim-bookworm"]
  args = {
    BASE_IMAGE      = "python:3.12-slim-bookworm"
    OPENSPP_VERSION = "17.0.1-daily+odoo17.0-1"
  }
  platforms = ["linux/amd64"]
}
