#!/bin/bash
set -e

echo "[$(date)] Starting Firecracker with the custom container..."
cd /opt/firecracker

# Check and fix KVM permissions
echo "[$(date)] Checking KVM device permissions..."
if [ ! -e /dev/kvm ]; then
    echo "[$(date)] ERROR: KVM device not found. Is KVM enabled on this system?"
    exit 1
fi

# Ensure KVM has proper permissions
chmod 666 /dev/kvm || {
    echo "[$(date)] Warning: Could not set permissions on /dev/kvm, continuing anyway"
}

# Check if KVM is actually usable
if ! kvm-ok &>/dev/null; then
    echo "[$(date)] Warning: KVM virtualization may not be fully supported in this environment"
    echo "[$(date)] Continuing anyway, but Firecracker may fail to start"
fi
echo "[$(date)] Set KVM device permissions to 666"

# Create necessary directories with proper permissions
mkdir -p /tmp/firecracker/logs
chmod 777 /tmp/firecracker/logs

# Generate and configure SSH keys
echo "[$(date)] Setting up SSH keys..."
ssh-keygen -t rsa -f /opt/firecracker/rootfs.id_rsa -N "" -C "root@firecracker"
mkdir -p /opt/firecracker/ssh_config
cp /opt/firecracker/rootfs.id_rsa.pub /opt/firecracker/ssh_config/authorized_keys
chmod 600 /opt/firecracker/rootfs.id_rsa

# Mount and configure rootfs
echo "[$(date)] Configuring rootfs SSH access..."
mkdir -p /mnt/rootfs
mount -t ext4 /opt/firecracker/rootfs.ext4 /mnt/rootfs
mkdir -p /mnt/rootfs/root/.ssh /mnt/rootfs/etc/ssh
cp /opt/firecracker/ssh_config/authorized_keys /mnt/rootfs/root/.ssh/
touch /mnt/rootfs/etc/ssh/ssh_known_hosts
chmod 700 /mnt/rootfs/root/.ssh
chmod 600 /mnt/rootfs/root/.ssh/authorized_keys
chmod 644 /mnt/rootfs/etc/ssh/ssh_known_hosts
sync
umount /mnt/rootfs

# Clean up any existing socket and log files
rm -f /tmp/firecracker.sock
rm -f /tmp/firecracker/logs/firecracker.log
touch /tmp/firecracker/logs/firecracker.log
chmod 666 /tmp/firecracker/logs/firecracker.log

# Setup network interface
TAP_DEV="tap0"
TAP_IP="172.16.0.1"
MASK_SHORT="/30"

# Create and configure tap device
ip link del "$TAP_DEV" 2> /dev/null || true
ip tuntap add dev "$TAP_DEV" mode tap
ip addr add "${TAP_IP}${MASK_SHORT}" dev "$TAP_DEV"
ip link set dev "$TAP_DEV" up

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -P FORWARD ACCEPT

# Set up NAT for outbound traffic
HOST_IFACE=$(ip -j route list default | grep -o '"dev":"[^"]*"' | cut -d'"' -f4)
# Add fallback if json parsing fails
if [ -z "$HOST_IFACE" ]; then
    HOST_IFACE=$(ip route | grep default | awk '{print $5}')
    echo "[$(date)] Using fallback method to determine host interface: $HOST_IFACE"
fi
iptables -t nat -D POSTROUTING -o "$HOST_IFACE" -j MASQUERADE 2>/dev/null || true
iptables -t nat -A POSTROUTING -o "$HOST_IFACE" -j MASQUERADE

# Create a JSON configuration for Firecracker
echo "[$(date)] Creating Firecracker configuration..."
cat > /tmp/firecracker_config.json << 'CONFIG_EOF'
{
  "boot-source": {
    "kernel_image_path": "/opt/firecracker/vmlinux.bin",
    "boot_args": "console=ttyS0 reboot=k panic=1 pci=off"
  },
  "drives": [
    {
      "drive_id": "rootfs",
      "path_on_host": "/opt/firecracker/rootfs.ext4",
      "is_root_device": true,
      "is_read_only": false
    }
  ],
  "machine-config": {
    "vcpu_count": 1,
    "mem_size_mib": 512
  },
  "network-interfaces": [
    {
      "iface_id": "net1",
      "guest_mac": "06:00:AC:10:00:02",
      "host_dev_name": "tap0"
    }
  ],
  "logger": {
    "log_path": "/tmp/firecracker/logs/firecracker.log",
    "level": "Debug",
    "show_level": true,
    "show_log_origin": true
  }
}
CONFIG_EOF

# Clean up any existing socket
rm -f /tmp/firecracker.sock

# Start Firecracker
echo "[$(date)] Launching Firecracker microVM..."
/opt/firecracker/firecracker --api-sock /tmp/firecracker.sock --config-file /tmp/firecracker_config.json &
FIRECRACKER_PID=$!
echo "[$(date)] Firecracker started with PID: $FIRECRACKER_PID"

# Wait for Firecracker to start
sleep 2

# Run a command inside the container with proper error handling
echo "[$(date)] Running a command inside the container..."
if ! ssh -v -o ConnectTimeout=5 \
       -o StrictHostKeyChecking=no \
       -o PasswordAuthentication=no \
       -o BatchMode=yes \
       -i /opt/firecracker/rootfs.id_rsa \
       root@172.16.0.2 "python --version && elixir --version"; then
    echo "[$(date)] ERROR: Failed to connect to the microVM"
    # Check SSH key permissions
    chmod 600 /opt/firecracker/rootfs.id_rsa
    echo "[$(date)] Fixed SSH key permissions, retrying..."
    ssh -v -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=no \
        -o PasswordAuthentication=no \
        -o BatchMode=yes \
        -i /opt/firecracker/rootfs.id_rsa \
        root@172.16.0.2 "python --version && elixir --version"
fi