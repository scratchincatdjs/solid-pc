#!/bin/bash
set -e

# Script to test ISO in QEMU VM
# Usage: ./test-iso.sh <ISO_PATH>

ISO_PATH="$1"

if [ -z "${ISO_PATH}" ]; then
    echo "Usage: $0 <ISO_PATH>"
    exit 1
fi

if [ ! -f "${ISO_PATH}" ]; then
    echo "ERROR: ISO file not found: ${ISO_PATH}"
    exit 1
fi

ISO_NAME=$(basename "${ISO_PATH}")

echo "Testing ISO: ${ISO_NAME}"
echo ""
echo "Launching QEMU VM..."
echo "- Memory: 4GB"
echo "- CPUs: 2"
echo "- Disk: 30GB (temporary test disk)"
echo "- Boot: UEFI"
echo ""
echo "Press Ctrl+Alt+G to release mouse/keyboard from VM"
echo "Close the QEMU window to stop the test"
echo ""

# Create temporary test disk
TEST_DISK="/tmp/solid-test-disk-$$.qcow2"
qemu-img create -f qcow2 "${TEST_DISK}" 30G

# Launch QEMU
qemu-system-x86_64 \
    -enable-kvm \
    -m 4096 \
    -smp 2 \
    -cdrom "${ISO_PATH}" \
    -drive file="${TEST_DISK}",format=qcow2,if=virtio \
    -boot d \
    -vga qxl \
    -display gtk \
    -net nic,model=virtio \
    -net user

# Cleanup
echo ""
echo "Test complete. Cleaning up..."
rm -f "${TEST_DISK}"
