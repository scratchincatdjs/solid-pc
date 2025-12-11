#!/bin/bash
set -e

# Customize the installer with BTRFS partitioning and SOLID customizations
# Usage: ./customize-installer.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${SCRIPT_DIR}/workspace"
SQUASHFS_DIR="${WORKSPACE}/squashfs"
PACKER_OUTPUT="../packer/output"

if [ ! -d "${WORKSPACE}" ]; then
    echo "ERROR: Workspace not found. Run extract-iso.sh first."
    exit 1
fi

echo "================================================"
echo "Customizing Installer"
echo "================================================"
echo ""

# Check if Packer output exists
if [ ! -d "${PACKER_OUTPUT}" ]; then
    echo "WARNING: Packer output not found at ${PACKER_OUTPUT}"
    echo "Skipping filesystem replacement."
    echo "The ISO will use the base Linux Mint filesystem."
    SKIP_FILESYSTEM=true
else
    SKIP_FILESYSTEM=false
fi

# Copy custom BTRFS partitioning script
echo "→ Installing custom BTRFS partitioning script..."
sudo mkdir -p "${SQUASHFS_DIR}/usr/share/solid-pc"
sudo cp templates/partition-btrfs.sh "${SQUASHFS_DIR}/usr/share/solid-pc/"
sudo chmod +x "${SQUASHFS_DIR}/usr/share/solid-pc/partition-btrfs.sh"

# Create installer preseed hooks directory
echo "→ Setting up installer hooks..."
sudo mkdir -p "${SQUASHFS_DIR}/usr/lib/ubiquity/user-setup"

# Add SOLID branding
echo "→ Adding SOLID branding..."
sudo mkdir -p "${SQUASHFS_DIR}/usr/share/pixmaps"
if [ -f "${SCRIPT_DIR}/assets/branding/solid-logo.png" ]; then
    sudo cp "${SCRIPT_DIR}/assets/branding/solid-logo.png" "${SQUASHFS_DIR}/usr/share/pixmaps/"
fi

# Customize installer slideshow (if custom slides exist)
if [ -d "${SCRIPT_DIR}/assets/installer-slides" ]; then
    echo "→ Customizing installer slideshow..."
    sudo cp -r "${SCRIPT_DIR}/assets/installer-slides/"* "${SQUASHFS_DIR}/usr/share/ubiquity-slideshow/slides/" || true
fi

# Update manifests
echo "→ Updating filesystem manifest..."
sudo chroot "${SQUASHFS_DIR}" dpkg-query -W --showformat='${Package} ${Version}\n' | sudo tee "${WORKSPACE}/extract/casper/filesystem.manifest" > /dev/null

echo ""
echo "================================================"
echo "Customization complete!"
echo "================================================"
echo ""
echo "Next step: Run rebuild-iso.sh"
