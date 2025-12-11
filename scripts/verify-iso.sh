#!/bin/bash
set -e

# Script to verify ISO checksums
# Usage: ./verify-iso.sh <ISO_PATH>

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
ISO_DIR=$(dirname "${ISO_PATH}")

# Try Ubuntu format first (SHA256SUMS), then Mint format (sha256sum.txt)
if [ -f "${ISO_DIR}/SHA256SUMS" ]; then
    SUMS_FILE="${ISO_DIR}/SHA256SUMS"
elif [ -f "${ISO_DIR}/sha256sum.txt" ]; then
    SUMS_FILE="${ISO_DIR}/sha256sum.txt"
else
    SUMS_FILE=""
fi

echo "Verifying ISO: ${ISO_NAME}"

# Check if checksums file exists
if [ -z "${SUMS_FILE}" ]; then
    echo "WARNING: SHA256SUMS or sha256sum.txt not found in ${ISO_DIR}"
    echo "Skipping checksum verification"
    echo ""
    echo "To verify manually, download SHA256SUMS from the mirror"
    exit 0
fi

# Extract expected checksum for this ISO
EXPECTED_SUM=$(grep "${ISO_NAME}" "${SUMS_FILE}" | awk '{print $1}')

if [ -z "${EXPECTED_SUM}" ]; then
    echo "WARNING: Checksum not found for ${ISO_NAME} in $(basename "${SUMS_FILE}")"
    echo "Skipping checksum verification"
    exit 0
fi

echo "Expected SHA256: ${EXPECTED_SUM}"
echo "Calculating SHA256 of ${ISO_NAME}..."

# Calculate actual checksum
ACTUAL_SUM=$(sha256sum "${ISO_PATH}" | awk '{print $1}')

echo "Actual SHA256:   ${ACTUAL_SUM}"
echo ""

# Compare
if [ "${EXPECTED_SUM}" = "${ACTUAL_SUM}" ]; then
    echo "✓ Checksum verification PASSED"
    echo "ISO is authentic and uncorrupted"
    exit 0
else
    echo "✗ Checksum verification FAILED"
    echo "The ISO file may be corrupted or tampered with"
    echo "Please re-download the ISO"
    exit 1
fi
