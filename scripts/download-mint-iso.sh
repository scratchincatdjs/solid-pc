#!/bin/bash
set -e

# Script to download Linux Mint ISO
# Usage: ./download-mint-iso.sh [VERSION] [FLAVOR]

VERSION=${1:-22}
FLAVOR=${2:-cinnamon-64bit}
ISO_NAME="linuxmint-${VERSION}-${FLAVOR}.iso"
DOWNLOAD_DIR="downloads"
ISO_PATH="${DOWNLOAD_DIR}/${ISO_NAME}"

# Mirror list (in order of preference)
MIRRORS=(
    "https://mirrors.layeronline.com/linuxmint/stable/${VERSION}"
    "https://mirror.math.princeton.edu/pub/linuxmint/stable/${VERSION}"
    "https://mirrors.edge.kernel.org/linuxmint/stable/${VERSION}"
    "https://ftp.heanet.ie/pub/linuxmint/stable/${VERSION}"
)

# Create download directory
mkdir -p "${DOWNLOAD_DIR}"

# Check if already downloaded
if [ -f "${ISO_PATH}" ]; then
    echo "ISO already exists at ${ISO_PATH}"
    echo "Run 'make clean-all' to re-download"
    exit 0
fi

echo "Downloading Linux Mint ${VERSION} ${FLAVOR} ISO..."
echo "ISO: ${ISO_NAME}"
echo ""

# Try each mirror until one succeeds
DOWNLOAD_SUCCESS=false
for MIRROR in "${MIRRORS[@]}"; do
    ISO_URL="${MIRROR}/${ISO_NAME}"
    echo "Trying mirror: ${MIRROR}"

    if wget -c -O "${ISO_PATH}.tmp" "${ISO_URL}"; then
        mv "${ISO_PATH}.tmp" "${ISO_PATH}"
        DOWNLOAD_SUCCESS=true
        echo ""
        echo "Download successful from ${MIRROR}"
        break
    else
        echo "Failed to download from ${MIRROR}"
        rm -f "${ISO_PATH}.tmp"
    fi
done

if [ "${DOWNLOAD_SUCCESS}" = false ]; then
    echo "ERROR: Failed to download ISO from all mirrors"
    exit 1
fi

# Download SHA256SUMS for verification
echo ""
echo "Downloading SHA256SUMS..."
for MIRROR in "${MIRRORS[@]}"; do
    SUMS_URL="${MIRROR}/sha256sum.txt"
    if wget -O "${DOWNLOAD_DIR}/sha256sum.txt" "${SUMS_URL}"; then
        echo "SHA256SUMS downloaded"
        break
    fi
done

echo ""
echo "Download complete: ${ISO_PATH}"
echo "Size: $(du -h "${ISO_PATH}" | cut -f1)"
