#!/bin/bash
set -e

# Cleanup Script
# Prepares the VM for imaging by removing temporary files,
# build artifacts, and sensitive information

echo "================================================"
echo "SOLID Linux Mint - Cleanup for Imaging"
echo "================================================"

# Clean package manager caches
echo "→ Cleaning package manager caches..."
apt-get autoremove -y
apt-get autoclean -y
apt-get clean -y

# Remove old kernels (keep current)
echo "→ Removing old kernels..."
dpkg --list | grep 'linux-image' | awk '{ print $2 }' | sort -V | sed -n '/'$(uname -r)'/q;p' | xargs -r apt-get -y purge || true

# Clean log files
echo "→ Cleaning log files..."
find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;
find /var/log -type f -name "*.gz" -delete
find /var/log -type f -name "*.1" -delete
find /tmp -type f -delete
find /var/tmp -type f -delete

# Remove machine-specific files that should be regenerated
echo "→ Removing machine-specific files..."
rm -f /etc/ssh/ssh_host_*
rm -f /var/lib/dbus/machine-id
rm -f /etc/machine-id
touch /etc/machine-id

# Clean bash history for build user
echo "→ Cleaning shell history..."
rm -f /home/solid/.bash_history
rm -f /root/.bash_history
history -c

# Remove cloud-init artifacts (if any)
echo "→ Removing cloud-init artifacts..."
cloud-init clean --logs --seed || true

# Clean network configuration (will be regenerated)
echo "→ Cleaning network configuration..."
rm -f /etc/netplan/*
rm -f /etc/NetworkManager/system-connections/*

# Remove temporary SSH keys for build user
echo "→ Cleaning SSH configuration..."
rm -rf /home/solid/.ssh/known_hosts
rm -rf /home/solid/.ssh/authorized_keys
rm -rf /root/.ssh/known_hosts

# Clean apt lists (will be regenerated on first boot)
echo "→ Cleaning apt lists..."
rm -rf /var/lib/apt/lists/*
mkdir -p /var/lib/apt/lists/partial

# Remove swap file references (final system will use swap on BTRFS)
echo "→ Cleaning swap configuration..."
swapoff -a || true
rm -f /swapfile

# Zero out free space for better compression (optional, takes time)
# Commented out by default as it significantly increases build time
# echo "→ Zeroing free space for compression..."
# dd if=/dev/zero of=/EMPTY bs=1M || true
# rm -f /EMPTY

# Sync filesystem
echo "→ Syncing filesystem..."
sync

echo "================================================"
echo "Cleanup complete!"
echo "VM ready for imaging"
echo "================================================"
