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
echo "Customizing Ubuntu Installer"
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

# Configure GRUB for fast boot
echo "→ Configuring GRUB for fast boot..."
sudo mkdir -p "${SQUASHFS_DIR}/etc/default/grub.d"
sudo tee "${SQUASHFS_DIR}/etc/default/grub.d/99-solid-performance.cfg" > /dev/null << 'EOF'
# SOLID Performance Settings
# Optimized for fast boot in virtualized and bare-metal environments
GRUB_TIMEOUT=2
GRUB_TIMEOUT_STYLE=hidden
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3 rd.systemd.show_status=auto rd.udev.log_level=3"
GRUB_RECORDFAIL_TIMEOUT=2
GRUB_DISABLE_OS_PROBER=true
EOF

# Update live boot grub.cfg timeout if present
if [ -f "${WORKSPACE}/extract/boot/grub/grub.cfg" ]; then
    echo "→ Updating live boot GRUB timeout..."
    sudo sed -i 's/set timeout=[0-9]*/set timeout=2/' "${WORKSPACE}/extract/boot/grub/grub.cfg" 2>/dev/null || true
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
