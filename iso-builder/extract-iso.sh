#!/bin/bash
set -e

# Extract Linux Mint ISO for customization
# Usage: ./extract-iso.sh <path-to-iso>

ISO_PATH="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${SCRIPT_DIR}/workspace"
MOUNT_DIR="${WORKSPACE}/mnt"
EXTRACT_DIR="${WORKSPACE}/extract"
SQUASHFS_DIR="${WORKSPACE}/squashfs"

if [ -z "${ISO_PATH}" ]; then
    echo "Usage: $0 <path-to-iso>"
    exit 1
fi

if [ ! -f "${ISO_PATH}" ]; then
    echo "ERROR: ISO not found: ${ISO_PATH}"
    exit 1
fi

echo "================================================"
echo "Extracting Linux Mint ISO"
echo "================================================"
echo "ISO: $(basename ${ISO_PATH})"
echo "Workspace: ${WORKSPACE}"
echo ""

# Clean up old workspace
if [ -d "${WORKSPACE}" ]; then
    echo "→ Cleaning old workspace..."
    sudo umount "${MOUNT_DIR}" 2>/dev/null || true
    sudo rm -rf "${WORKSPACE}"
fi

# Create workspace directories
echo "→ Creating workspace directories..."
mkdir -p "${MOUNT_DIR}"
mkdir -p "${EXTRACT_DIR}"
mkdir -p "${SQUASHFS_DIR}"

# Mount ISO
echo "→ Mounting ISO..."
sudo mount -o loop "${ISO_PATH}" "${MOUNT_DIR}"

# Copy ISO contents
echo "→ Copying ISO contents (this may take a few minutes)..."
sudo rsync -a --exclude=casper/filesystem.squashfs "${MOUNT_DIR}/" "${EXTRACT_DIR}/"

# Make extract directory writable
sudo chmod -R u+w "${EXTRACT_DIR}"

# Extract squashfs filesystem
echo "→ Extracting squashfs filesystem (this will take several minutes)..."
sudo unsquashfs -d "${SQUASHFS_DIR}" "${MOUNT_DIR}/casper/filesystem.squashfs"

# Unmount ISO
echo "→ Unmounting ISO..."
sudo umount "${MOUNT_DIR}"

# Set permissions
echo "→ Setting permissions..."
sudo chown -R $(whoami):$(whoami) "${WORKSPACE}" || true

echo ""
echo "================================================"
echo "Extraction complete!"
echo "================================================"
echo "ISO contents: ${EXTRACT_DIR}"
echo "Filesystem:   ${SQUASHFS_DIR}"
echo ""
echo "Next step: Run customize-installer.sh"
