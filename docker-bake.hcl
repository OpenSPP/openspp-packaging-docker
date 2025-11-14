
variable "PUSH_REGISTRY" {
  default = "docker-push.acn.fr"
}
variable "REGISTRY" {
  default = "docker.acn.fr"
}
variable "REPO" {
  default = "openspp/openspp"
}
variable "IMAGE_NAME" {
  default = "${REGISTRY}/${REPO}"
}
variable "PUSH_IMAGE_NAME" {
  default = "${PUSH_REGISTRY}/${REPO}"
}
variable "IMAGE_TAG" {
  default = "daily"
}

group "default" {
  targets = [
    # "openspp-debian-bookworm-slim",
    # "openspp-debian-trixie-slim",
    "openspp-ubuntu-24-04",
    # "openspp-python-3-14-slim-bookworm",
    # "openspp-python-3-13-slim-bookworm",
    # "openspp-python-3-12-slim-bookworm"
  ]
}

target "common" {
  args = {
    BUILD_DATE              = "$(date -u +\"%Y-%m-%dT%H:%M:%SZ\")"
    DEBIAN_FRONTEND         = "noninteractive"
    GID                     = "1001"
    OPENSPP_VERSION         = "17.0.1-daily+odoo17.0-1"
    PYTHONUNBUFFERED        = "1"
    PYTHONDONTWRITEBYTECODE = "1"
    TARGETARCH              = "amd64"
    UID                     = "1001"
    VCS_REF                 = "master"    
    OPENSPP_LEFT_TO_RIGHT_LANGUAGE_SUPPORT = "false"
  }
}

target "openspp-debian-bookworm-slim" {
  inherits   = ["common"]
  context    = "."
  dockerfile = "Dockerfile"
  tags = [
    "${IMAGE_NAME}:debian-bookworm-slim-${IMAGE_TAG}",
    "${PUSH_IMAGE_NAME}:debian-bookworm-slim-${IMAGE_TAG}"
  ]
  args = {
    BASE_IMAGE      = "debian:bookworm-slim"
    
  }
  platforms = ["linux/amd64"]
}

target "openspp-debian-trixie-slim" {
  inherits   = ["common"]
  context    = "."
  dockerfile = "Dockerfile"
  tags = [
    "${IMAGE_NAME}:debian-trixie-slim-${IMAGE_TAG}",
    "${PUSH_IMAGE_NAME}:debian-trixie-slim-${IMAGE_TAG}"
  ]
  args = {
    BASE_IMAGE      = "debian:trixie-slim"
  }
  platforms = ["linux/amd64"]
}

target "openspp-ubuntu-24-04" {
  inherits   = ["common"]
  context    = "."
  dockerfile = "Dockerfile"
  tags = [
    "${IMAGE_NAME}:ubuntu-24.04-${IMAGE_TAG}",
    "${PUSH_IMAGE_NAME}:ubuntu-24.04-${IMAGE_TAG}"
  ]
  args = {
    BASE_IMAGE      = "ubuntu:24.04"
  }
  platforms = ["linux/amd64"]
}

target "openspp-python-3-14-slim-bookworm" {
  inherits   = ["common"]
  context    = "."
  dockerfile = "Dockerfile"
  tags = [
    "${IMAGE_NAME}:python-3-14-slim-bookworm-${IMAGE_TAG}",
    "${PUSH_IMAGE_NAME}:python-3-14-slim-bookworm-${IMAGE_TAG}"
  ]
  args = {
    BASE_IMAGE      = "python:3.14-slim-bookworm"
  }
  platforms = ["linux/amd64"]
}

target "openspp-python-3-13-slim-bookworm" {
  inherits   = ["common"]
  context    = "."
  dockerfile = "Dockerfile"
  tags = [
    "${IMAGE_NAME}:python-3-13-slim-bookworm-${IMAGE_TAG}",
    "${PUSH_IMAGE_NAME}:python-3-13-slim-bookworm-${IMAGE_TAG}"
  ]
  args = {
    BASE_IMAGE      = "python:3.13-slim-bookworm"
  }
  platforms = ["linux/amd64"]
}

target "openspp-python-3-12-slim-bookworm" {
  inherits   = ["common"]
  context    = "."
  dockerfile = "Dockerfile"
  tags = [
    "${IMAGE_NAME}:python-3-12-slim-bookworm-${IMAGE_TAG}",
    "${PUSH_IMAGE_NAME}:python-3-12-slim-bookworm-${IMAGE_TAG}"
  ]
  args = {
    BASE_IMAGE      = "python:3.12-slim-bookworm"
  }
  platforms = ["linux/amd64"]
}
