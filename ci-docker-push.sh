#!/bin/bash
# ABOUTME: Push Docker images to Nexus registry using internal IP
# ABOUTME: Based on working pattern from openspp-packaging-v2

set -e

# Configuration - using internal Docker network IP
NEXUS_DOCKER="172.20.0.26:8082"
NEXUS_USER="${NEXUS_USER}"
NEXUS_PASSWORD="${NEXUS_PASSWORD}"

# Check credentials
if [ -z "$NEXUS_USER" ] || [ -z "$NEXUS_PASSWORD" ]; then
    echo "Error: NEXUS_USER and NEXUS_PASSWORD must be set"
    echo "Try: export NEXUS_USER=your_username"
    echo "     export NEXUS_PASSWORD=your_password"
    exit 1
fi

echo "=== Docker Push to Nexus Registry ==="
echo "Registry: $NEXUS_DOCKER (Internal IP)"
echo

# Test connectivity
echo "Testing connection to Nexus Docker registry..."
if nc -zv 172.20.0.26 8082 2>/dev/null; then
    echo "✓ Port 8082 is reachable"
else
    echo "✗ Cannot reach 172.20.0.26:8082"
    echo "  This script must run from within the Docker network"
    exit 1
fi

# Login to registry
echo "Logging in to Docker registry..."
echo "$NEXUS_PASSWORD" | docker login "$NEXUS_DOCKER" -u "$NEXUS_USER" --password-stdin
if [ $? -eq 0 ]; then
    echo "✓ Login successful"
else
    echo "✗ Login failed"
    echo "  Check credentials and registry configuration"
    exit 1
fi

# Determine what to push
if [ -n "$1" ]; then
    # Specific image provided
    SOURCE_IMAGE="$1"
else
    # Default to openspp:latest
    SOURCE_IMAGE="openspp:latest"
fi

echo
echo "Preparing to push: $SOURCE_IMAGE"

# Check if image exists locally
if ! docker image inspect "$SOURCE_IMAGE" >/dev/null 2>&1; then
    echo "✗ Image not found locally: $SOURCE_IMAGE"
    echo "  Build it first with: docker build -t $SOURCE_IMAGE ."
    exit 1
fi

# Tag for Nexus registry
TARGET_IMAGE="$NEXUS_DOCKER/openspp/openspp:latest"
if [ "$SOURCE_IMAGE" != "openspp:latest" ]; then
    # Preserve specific tags
    TAG="${SOURCE_IMAGE#*:}"
    if [ "$TAG" = "$SOURCE_IMAGE" ]; then
        TAG="latest"
    fi
    TARGET_IMAGE="$NEXUS_DOCKER/openspp/openspp:$TAG"
fi

echo "Tagging as: $TARGET_IMAGE"
docker tag "$SOURCE_IMAGE" "$TARGET_IMAGE"

# Push to registry
echo "Pushing image..."
if docker push "$TARGET_IMAGE"; then
    echo "✓ Successfully pushed: $TARGET_IMAGE"
else
    echo "✗ Push failed"
    exit 1
fi

# Also push additional tags if this is a release
if [ -n "$CI_COMMIT_TAG" ]; then
    echo
    echo "Detected tag: $CI_COMMIT_TAG"
    
    # Push with version tag
    VERSION_TAG="$NEXUS_DOCKER/openspp/openspp:$CI_COMMIT_TAG"
    docker tag "$SOURCE_IMAGE" "$VERSION_TAG"
    docker push "$VERSION_TAG"
    echo "✓ Pushed version tag: $VERSION_TAG"
    
    # Update latest tag
    LATEST_TAG="$NEXUS_DOCKER/openspp/openspp:latest"
    docker tag "$SOURCE_IMAGE" "$LATEST_TAG"
    docker push "$LATEST_TAG"
    echo "✓ Updated latest tag: $LATEST_TAG"
fi

# Push commit SHA tag if available
if [ -n "$CI_COMMIT_SHA" ]; then
    SHORT_SHA="${CI_COMMIT_SHA:0:8}"
    SHA_TAG="$NEXUS_DOCKER/openspp/openspp:$SHORT_SHA"
    docker tag "$SOURCE_IMAGE" "$SHA_TAG"
    docker push "$SHA_TAG"
    echo "✓ Pushed commit tag: $SHA_TAG"
fi

echo
echo "=== Push Summary ==="
echo "✓ Image successfully pushed to Nexus"
echo "  Registry: $NEXUS_DOCKER"
echo "  Repository: openspp/openspp"
echo
echo "To pull this image from another machine:"
echo "  docker pull $TARGET_IMAGE"