#!/bin/bash
set -e

# Script to test ISO in QEMU VM (optimized for nested virtualization)
# Usage: ./test-iso.sh <ISO_PATH> [--gtk|--console]
#
# By default, runs headless with VNC on port 5900 for best performance
# in nested virtualization environments.

ISO_PATH="$1"
DISPLAY_MODE="headless"  # Default to headless (VNC) for nested virt performance

# Parse additional arguments
shift 2>/dev/null || true
while [[ $# -gt 0 ]]; do
    case $1 in
        --gtk)
            DISPLAY_MODE="gtk"
            shift
            ;;
        --console)
            DISPLAY_MODE="console"
            shift
            ;;
        --headless)
            DISPLAY_MODE="headless"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

if [ -z "${ISO_PATH}" ]; then
    echo "Usage: $0 <ISO_PATH> [--gtk|--console|--headless]"
    echo ""
    echo "Display modes:"
    echo "  --headless   VNC on port 5900 (default, fastest for nested virt)"
    echo "  --gtk        GTK window (requires X11)"
    echo "  --console    Text console (for SSH/terminal sessions)"
    exit 1
fi

if [ ! -f "${ISO_PATH}" ]; then
    echo "ERROR: ISO file not found: ${ISO_PATH}"
    exit 1
fi

ISO_NAME=$(basename "${ISO_PATH}")

echo "Testing ISO: ${ISO_NAME}"
echo ""
echo "Launching QEMU VM (optimized for nested virtualization)..."
echo "- Memory: 4GB"
echo "- CPUs: 2 (host passthrough)"
echo "- Machine: q35"
echo "- Disk: 30GB (temporary test disk)"
echo "- Boot: UEFI"
echo ""

# Set display arguments based on mode
case $DISPLAY_MODE in
    gtk)
        DISPLAY_ARGS="-display gtk -vga virtio"
        echo "Display: GTK window"
        echo "Press Ctrl+Alt+G to release mouse/keyboard from VM"
        ;;
    console)
        DISPLAY_ARGS="-display curses -vga std"
        echo "Display: Text console"
        ;;
    headless)
        DISPLAY_ARGS="-display none -vnc :0 -vga virtio"
        echo "Display: Headless (VNC on port 5900)"
        echo ""
        echo "Connect with: vncviewer localhost:5900"
        ;;
esac

echo "Close the QEMU window or press Ctrl+C to stop the test"
echo ""

# Create temporary test disk
TEST_DISK="/tmp/solid-test-disk-$$.qcow2"
qemu-img create -f qcow2 "${TEST_DISK}" 30G

# Cleanup function
cleanup() {
    echo ""
    echo "Test complete. Cleaning up..."
    rm -f "${TEST_DISK}"
}
trap cleanup EXIT

# Launch QEMU with performance optimizations for nested virtualization
qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -machine type=q35,accel=kvm \
    -m 4096 \
    -smp 2,sockets=1,cores=2,threads=1 \
    -cdrom "${ISO_PATH}" \
    -drive file="${TEST_DISK}",format=qcow2,if=virtio,cache=writeback,discard=unmap \
    -boot d \
    ${DISPLAY_ARGS} \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0 \
    -usb \
    -device usb-tablet
