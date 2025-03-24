#!/bin/bash
set -e

echo "[$(date)] Creating container build directory..."
CONTAINER_DIR="container"
mkdir -p $CONTAINER_DIR
cd $CONTAINER_DIR || {
  echo "[$(date)] ERROR: Failed to create or access container directory"
  exit 1  # Fixed typo: removed 'x'
}

# Build the Docker image with error checking
echo "[$(date)] Building Docker image..."
if ! docker build -t python-elixir-container:latest .; then
  echo "[$(date)] ERROR: Docker image build failed"
  exit 1
fi
echo "[$(date)] Docker image built successfully"

# Save the Docker image with error checking
echo "[$(date)] Saving Docker image to tar file..."
if ! docker save -o python-elixir-container.tar python-elixir-container:latest; then
  echo "[$(date)] ERROR: Failed to save Docker image"
  exit 1
fi
echo "[$(date)] Docker image saved successfully to $CONTAINER_DIR/python-elixir-container.tar"

# Verify the tar file exists and has content
if [ ! -s python-elixir-container.tar ]; then
  echo "[$(date)] ERROR: Docker image tar file is empty or not created"
  exit 1
fi