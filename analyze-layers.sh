#!/bin/bash
# ABOUTME: Script to analyze Docker image layers and find redundancy
# ABOUTME: Helps identify duplicate layers and optimization opportunities

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default image
IMAGE="${1:-openspp:test}"

echo -e "${BLUE}Docker Layer Analysis for: $IMAGE${NC}"
echo "================================================"

# Check if image exists
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo -e "${RED}Error: Image '$IMAGE' not found${NC}"
    echo "Usage: $0 [image-name]"
    exit 1
fi

# 1. Show layer sizes
echo -e "\n${YELLOW}Layer Sizes:${NC}"
docker history "$IMAGE" --format "table {{.Size}}\t{{.CreatedBy}}" | head -20

# 2. Find duplicate sizes
echo -e "\n${YELLOW}Checking for duplicate layer sizes:${NC}"
docker history "$IMAGE" --format "{{.Size}}" | \
    grep -v "<missing>" | \
    sort | uniq -d | while read size; do
    if [ ! -z "$size" ] && [ "$size" != "0B" ]; then
        echo -e "${RED}Found duplicate size: $size${NC}"
        echo "Layers with this size:"
        docker history "$IMAGE" --format "{{.Size}}\t{{.CreatedBy}}" | grep "^$size"
    fi
done

# 3. Calculate total image size
echo -e "\n${YELLOW}Image Size Analysis:${NC}"
SIZE=$(docker image inspect "$IMAGE" --format='{{.Size}}')
SIZE_MB=$((SIZE / 1024 / 1024))
echo "Total image size: ${SIZE_MB}MB"

# 4. Show largest layers
echo -e "\n${YELLOW}Top 5 Largest Layers:${NC}"
docker history "$IMAGE" --format "table {{.Size}}\t{{.CreatedBy}}" | \
    grep -v SIZE | \
    sort -hr | \
    head -5

# 5. Check for common anti-patterns
echo -e "\n${YELLOW}Checking for common anti-patterns:${NC}"

# Check for chown after COPY
if docker history "$IMAGE" --no-trunc | grep -q "COPY.*from=.*installer" && \
   docker history "$IMAGE" --no-trunc | grep -q "chown.*openspp"; then
    echo -e "${RED}⚠ Warning: Found COPY followed by chown - consider using COPY --chown${NC}"
fi

# Check for multiple apt-get updates
APT_UPDATES=$(docker history "$IMAGE" --no-trunc | grep -c "apt-get update" || true)
if [ "$APT_UPDATES" -gt 2 ]; then
    echo -e "${YELLOW}⚠ Found $APT_UPDATES apt-get update commands - consider combining${NC}"
fi

# Check for rm commands that might be ineffective
if docker history "$IMAGE" --no-trunc | grep -q "rm -rf /var/lib/apt/lists"; then
    echo -e "${GREEN}✓ Good: Cleaning apt cache${NC}"
fi

# 6. Suggest dive tool if not installed
if ! command -v dive &> /dev/null; then
    echo -e "\n${BLUE}For detailed layer analysis, install dive:${NC}"
    echo "  brew install dive    # macOS"
    echo "  wget https://github.com/wagoodman/dive/releases/latest/download/dive_*_linux_amd64.deb"
    echo "  sudo dpkg -i dive_*.deb    # Ubuntu/Debian"
    echo ""
    echo "Then run: dive $IMAGE"
else
    echo -e "\n${GREEN}Dive is installed. Run 'dive $IMAGE' for interactive analysis${NC}"
fi

# 7. Export detailed analysis
echo -e "\n${YELLOW}Exporting detailed analysis...${NC}"
REPORT_FILE="layer-analysis-$(date +%Y%m%d-%H%M%S).txt"
{
    echo "Docker Layer Analysis Report"
    echo "Image: $IMAGE"
    echo "Date: $(date)"
    echo "================================"
    echo ""
    echo "Full Layer History:"
    docker history --no-trunc "$IMAGE"
    echo ""
    echo "Layer SHA256 Hashes:"
    docker inspect "$IMAGE" | jq '.[0].RootFS.Layers'
} > "$REPORT_FILE"

echo -e "${GREEN}Detailed report saved to: $REPORT_FILE${NC}"

# Summary
echo -e "\n${BLUE}Summary:${NC}"
LAYERS=$(docker history "$IMAGE" | wc -l)
echo "- Total layers: $LAYERS"
echo "- Image size: ${SIZE_MB}MB"

# Optimization suggestions
echo -e "\n${BLUE}Optimization Tips:${NC}"
echo "1. Use COPY --chown instead of separate chown commands"
echo "2. Combine multiple RUN commands with && to reduce layers"
echo "3. Order commands from least to most frequently changing"
echo "4. Clean package manager cache in the same RUN command"
echo "5. Use multi-stage builds to exclude build dependencies"