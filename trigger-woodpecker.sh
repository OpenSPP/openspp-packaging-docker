#!/bin/bash
# ABOUTME: Script to trigger Woodpecker CI build via empty commit
# ABOUTME: Workaround for manual pipeline trigger UI bug

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Triggering Woodpecker CI build...${NC}"

# Create an empty commit to trigger the pipeline
git commit --allow-empty -m "ci: trigger build [skip ci]"

# Remove [skip ci] if you want to trigger
git commit --amend -m "ci: trigger build"

# Push to trigger the pipeline
git push

echo -e "${GREEN}✓ Pipeline triggered via commit push${NC}"
echo "Check your Woodpecker instance for the build status"