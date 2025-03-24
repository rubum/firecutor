#!/bin/bash
set -e

echo "[$(date)] Preparing root filesystem for Firecracker..."
# cd /opt/firecracker

# Verify Docker image exists
if [ ! -f container/python-elixir-container.tar ]; then
  echo "[$(date)] ERROR: Docker image tar file not found"
  exit 1
fi

# Load the Docker image
echo "[$(date)] Loading Docker image..."
if ! docker load -i container/python-elixir-container.tar; then
  echo "[$(date)] ERROR: Failed to load Docker image"
  exit 1
fi

# Create a temporary container
echo "[$(date)] Creating temporary container..."
CONTAINER_ID=$(docker create python-elixir-container:latest)
if [ -z "$CONTAINER_ID" ]; then
  echo "[$(date)] ERROR: Failed to create container"
  exit 1
fi

# Export the container filesystem
echo "[$(date)] Exporting container filesystem..."
if ! docker export "$CONTAINER_ID" > /tmp/container.tar; then
  echo "[$(date)] ERROR: Failed to export container filesystem"
  docker rm "$CONTAINER_ID"
  exit 1
fi

# Create and mount rootfs
echo "[$(date)] Creating rootfs..."
dd if=/dev/zero of=rootfs.ext4 bs=1M count=1024
mkfs.ext4 rootfs.ext4

MOUNT_DIR="/mnt/rootfs"
mkdir -p "$MOUNT_DIR"
if ! mount -o loop rootfs.ext4 "$MOUNT_DIR"; then
  echo "[$(date)] ERROR: Failed to mount rootfs"
  exit 1
fi

# Extract the container filesystem
echo "[$(date)] Extracting container filesystem..."
if ! tar -xf /tmp/container.tar -C "$MOUNT_DIR"; then
  echo "[$(date)] ERROR: Failed to extract container filesystem"
  umount "$MOUNT_DIR"
  exit 1
fi

# Cleanup
umount "$MOUNT_DIR"
rm -rf "$MOUNT_DIR"
docker rm "$CONTAINER_ID"
rm /tmp/container.tar

echo "[$(date)] Root filesystem preparation completed successfully"