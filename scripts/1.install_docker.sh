#!/bin/bash
set -e

echo "[$(date)] Starting Docker installation..."
apt-get update
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  software-properties-common
echo "[$(date)] Added Docker prerequisites"

# Install Docker's GPG key without TTY interaction
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --batch --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository using the signed key
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "[$(date)] Added Docker repository"

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

# Add Docker user to KVM group
echo "[$(date)] Configuring KVM access for Docker..."
if getent group kvm > /dev/null; then
    DEFAULT_USER=$(getent passwd 1000 | cut -d: -f1)
    usermod -aG kvm $DEFAULT_USER
    usermod -aG kvm root
    echo "[$(date)] Added users '$DEFAULT_USER' and 'root' to KVM group"
else
    echo "[$(date)] Warning: KVM group not found, skipping group assignment"
fi

# Ensure Docker service has access to KVM
if [ -e /dev/kvm ]; then
    chmod 666 /dev/kvm
    echo "[$(date)] Set permissions 666 on /dev/kvm"
else
    echo "[$(date)] Warning: /dev/kvm device not found, skipping permission setup"
fi

# Verify Docker installation
if docker --version; then
    echo "[$(date)] Docker installed successfully: $(docker --version)"
else
    echo "[$(date)] ERROR: Docker installation failed"
    exit 1
fi

# Check Docker service status
if systemctl is-active --quiet docker; then
    echo "[$(date)] Docker service is running"
else
    echo "[$(date)] ERROR: Docker service is not running"
    exit 1
fi