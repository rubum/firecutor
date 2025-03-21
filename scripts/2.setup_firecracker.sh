#!/bin/bash
set -e

echo "[$(date)] Starting Firecracker setup..."
apt-get update
apt-get install -y \
  curl \
  git \
  build-essential \
  libssl-dev \
  uuid-dev \
  libseccomp-dev \
  pkg-config \
  python3 \
  python3-pip

# Setup KVM access with both group-based and ACL-based permissions
apt-get install -y qemu-kvm acl

# Load KVM kernel modules
modprobe kvm || echo "[$(date)] Warning: Could not load kvm module, may be running in a VM"
# Check CPU type and load appropriate module
if grep -q Intel /proc/cpuinfo; then
    modprobe kvm_intel || echo "[$(date)] Warning: Could not load kvm_intel module, may be running in a nested VM"
elif grep -q AMD /proc/cpuinfo; then
    modprobe kvm_amd || echo "[$(date)] Warning: Could not load kvm_amd module, may be running in a nested VM"
fi

# Create KVM device if it doesn't exist
if [ ! -e /dev/kvm ]; then
    mknod /dev/kvm c 10 232
fi

# Set permissions using both methods
# 1. Group-based permissions
usermod -aG kvm vagrant
chmod a+rw /dev/kvm

# 2. ACL-based permissions (as a fallback)
setfacl -m u:vagrant:rw /dev/kvm

# Verify KVM is working
if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    echo "[$(date)] KVM device node is accessible"
else
    echo "[$(date)] ERROR: Failed to make KVM device node accessible"
    exit 1
fi

# Install Firecracker
FIRECRACKER_VERSION="v1.11.0"
mkdir -p /opt/firecracker
cd /opt/firecracker

# Clean up existing socket and directories
rm -f /tmp/firecracker.sock
rm -rf firecracker_src

# Clone and build Firecracker
git clone https://github.com/firecracker-microvm/firecracker firecracker_src
systemctl start docker
./firecracker_src/tools/devtool build

# Set architecture and copy binary
ARCH="x86_64"
cp ./firecracker_src/build/cargo_target/${ARCH}-unknown-linux-musl/debug/firecracker /opt/firecracker/firecracker

# Generate SSH key for rootfs access (with force overwrite)
rm -f rootfs.id_rsa*
ssh-keygen -t rsa -f rootfs.id_rsa -N "" -q

# Set proper permissions
chmod 600 rootfs.id_rsa*

# Download and set up images
curl -Lo vmlinux.bin "https://github.com/firecracker-microvm/firecracker/blob/main/resources/guest_configs/x86_64/linux/vmlinux.bin?raw=true"
curl -fsSL --progress-bar -o rootfs.ext4 "https://s3.amazonaws.com/spec.ccfc.min/img/quickstart_guide/x86_64/rootfs/bionic.rootfs.ext4"

# Set up network bridge
ip link show fc-br0 > /dev/null 2>&1 || {
    ip link add name fc-br0 type bridge
    ip addr add 172.16.0.1/24 dev fc-br0
    ip link set fc-br0 up
}

# Set proper permissions
chmod +x /opt/firecracker/firecracker

# Download rootfs with progress and error handling
if ! curl -fsSL --progress-bar -o rootfs.ext4 "https://s3.amazonaws.com/spec.ccfc.min/img/quickstart_guide/x86_64/rootfs/bionic.rootfs.ext4"; then
    echo "[$(date)] ERROR: Failed to download rootfs image"
    exit 1
fi

# Set up the environment
echo "export PATH=\$PATH:/opt/firecracker" >> /etc/profile
source /etc/profile

# Download the correct kernel image
curl -Lo vmlinux.bin "https://s3.amazonaws.com/spec.ccfc.min/img/quickstart_guide/x86_64/kernels/vmlinux.bin"

# Verify the kernel image was downloaded correctly
if [ ! -s vmlinux.bin ]; then
    echo "[$(date)] ERROR: Failed to download kernel image"
    exit 1
fi
chmod +r vmlinux.bin