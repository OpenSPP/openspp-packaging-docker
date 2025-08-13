#!/bin/bash
# ABOUTME: Configure Docker daemon to allow insecure registry
# ABOUTME: Run this on the Woodpecker agent host

echo "Configuring Docker to allow insecure registry at 172.20.0.26:8082"

# Check if daemon.json exists
if [ -f /etc/docker/daemon.json ]; then
    echo "Backing up existing daemon.json..."
    sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup
fi

# Create or update daemon.json
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "insecure-registries": ["172.20.0.26:8082"]
}
EOF

echo "Configuration written to /etc/docker/daemon.json"
echo "Restarting Docker daemon..."
sudo systemctl restart docker

echo "Verifying configuration..."
docker info | grep -A 5 "Insecure Registries"

echo ""
echo "Testing registry access..."
curl -I http://172.20.0.26:8082/v2/ 2>/dev/null | head -1

echo ""
echo "Configuration complete! The Woodpecker builds should now work."
echo "You can test with: docker pull 172.20.0.26:8082/openspp/openspp:latest"