#!/bin/bash
set -e

# Rebuild bootable ISO from customized filesystem
# Usage: ./rebuild-iso.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${SCRIPT_DIR}/workspace"
EXTRACT_DIR="${WORKSPACE}/extract"
SQUASHFS_DIR="${WORKSPACE}/squashfs"
OUTPUT_DIR="$(cd ${SCRIPT_DIR}/.. && pwd)/output"
OUTPUT_ISO="${OUTPUT_DIR}/solid-ubuntu-24.04.iso"

if [ ! -d "${WORKSPACE}" ]; then
    echo "ERROR: Workspace not found. Run extract-iso.sh first."
    exit 1
fi

echo "================================================"
echo "Rebuilding Bootable ISO"
echo "================================================"
echo ""

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Rebuild squashfs filesystem
echo "→ Rebuilding squashfs filesystem (this will take several minutes)..."
sudo rm -f "${EXTRACT_DIR}/casper/filesystem.squashfs"
sudo mksquashfs "${SQUASHFS_DIR}" "${EXTRACT_DIR}/casper/filesystem.squashfs" \
    -comp xz \
    -b 1M \
    -Xbcj x86 \
    -e boot

# Update filesystem size
echo "→ Updating filesystem size..."
printf $(sudo du -sx --block-size=1 "${SQUASHFS_DIR}" | cut -f1) | sudo tee "${EXTRACT_DIR}/casper/filesystem.size" > /dev/null

# Calculate MD5 checksums
echo "→ Calculating MD5 checksums..."
cd "${EXTRACT_DIR}"
sudo rm -f md5sum.txt
find . -type f -print0 | sudo xargs -0 md5sum | grep -v isolinux/boot.cat | sudo tee md5sum.txt > /dev/null

# Rebuild ISO
echo "→ Rebuilding ISO (this may take a few minutes)..."
sudo xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "SOLID Ubuntu" \
    -eltorito-boot isolinux/isolinux.bin \
    -eltorito-catalog isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -isohybrid-apm-hfsplus \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -output "${OUTPUT_ISO}" \
    "${EXTRACT_DIR}"

# Make ISO hybrid (bootable from USB)
echo "→ Making ISO hybrid-bootable..."
sudo isohybrid --uefi "${OUTPUT_ISO}" 2>/dev/null || true

# Generate checksums for final ISO
echo "→ Generating checksums..."
cd "${OUTPUT_DIR}"
sha256sum $(basename "${OUTPUT_ISO}") | tee sha256sum.txt

# Set permissions
sudo chown $(whoami):$(whoami) "${OUTPUT_ISO}"
sudo chmod 644 "${OUTPUT_ISO}"

# Display info
ISO_SIZE=$(du -h "${OUTPUT_ISO}" | cut -f1)

echo ""
echo "================================================"
echo "ISO Build Complete!"
echo "================================================"
echo "Output: ${OUTPUT_ISO}"
echo "Size:   ${ISO_SIZE}"
echo ""
echo "SHA256: $(sha256sum ${OUTPUT_ISO} | cut -d' ' -f1)"
echo ""
echo "To write to USB drive:"
echo "  sudo dd if=${OUTPUT_ISO} of=/dev/sdX bs=4M status=progress && sync"
echo ""
echo "To test in VM:"
echo "  make test-iso"
