#!/bin/bash
# ABOUTME: Script to trigger Woodpecker builds using CLI
# ABOUTME: Alternative to UI for manual pipeline triggers

# Configuration (update these)
WOODPECKER_SERVER="${WOODPECKER_SERVER:-https://ci.yourdomain.com}"
WOODPECKER_TOKEN="${WOODPECKER_TOKEN:-your-personal-token}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if woodpecker-cli is installed
if ! command -v woodpecker-cli &> /dev/null; then
    echo -e "${YELLOW}Installing Woodpecker CLI...${NC}"
    
    # Detect OS and install accordingly
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        brew install woodpecker-cli
    else
        # Linux - download latest release
        curl -L https://github.com/woodpecker-ci/woodpecker/releases/latest/download/woodpecker-cli_linux_amd64.tar.gz | tar xz
        sudo mv woodpecker-cli /usr/local/bin/
    fi
fi

# Export environment variables for woodpecker-cli
export WOODPECKER_SERVER
export WOODPECKER_TOKEN

# Get repository info
REPO_NAME=$(basename $(git rev-parse --show-toplevel))
REPO_OWNER=$(git remote get-url origin | sed 's/.*[:/]\([^/]*\)\/.*/\1/')
BRANCH=$(git branch --show-current)

echo -e "${BLUE}Repository: ${REPO_OWNER}/${REPO_NAME}${NC}"
echo -e "${BLUE}Branch: ${BRANCH}${NC}"

# List recent pipelines
echo -e "\n${YELLOW}Recent pipelines:${NC}"
woodpecker-cli pipeline ls "${REPO_OWNER}/${REPO_NAME}" --limit 5

# Trigger new build
echo -e "\n${YELLOW}Triggering new build...${NC}"
woodpecker-cli pipeline create "${REPO_OWNER}/${REPO_NAME}" "${BRANCH}"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Pipeline triggered successfully${NC}"
    
    # Get the latest pipeline info
    echo -e "\n${YELLOW}Latest pipeline status:${NC}"
    woodpecker-cli pipeline last "${REPO_OWNER}/${REPO_NAME}"
else
    echo -e "${RED}✗ Failed to trigger pipeline${NC}"
    echo "Please check your WOODPECKER_SERVER and WOODPECKER_TOKEN environment variables"
fi