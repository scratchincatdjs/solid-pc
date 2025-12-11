#!/bin/bash
set -e

# Custom BTRFS partitioning script for SOLID Linux Mint
# This script is called during installation to create BTRFS partitions
# with proper subvolumes for Timeshift snapshots

DISK="${1:-/dev/sda}"

echo "================================================"
echo "SOLID Linux Mint - BTRFS Partitioning"
echo "================================================"
echo "Target disk: ${DISK}"
echo ""
echo "This will:"
echo "  1. Create GPT partition table"
echo "  2. Create EFI System Partition (512MB)"
echo "  3. Create LUKS encrypted partition (remaining space)"
echo "  4. Format as BTRFS with @ and @home subvolumes"
echo ""

# Confirm (in automated install this is pre-confirmed)
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Unmount any existing mounts
umount ${DISK}* 2>/dev/null || true

# Wipe existing partition table
echo "→ Wiping partition table..."
sgdisk --zap-all ${DISK}

# Create GPT partition table
echo "→ Creating GPT partition table..."
parted ${DISK} --script mklabel gpt

# Create EFI System Partition (512MB)
echo "→ Creating EFI System Partition..."
parted ${DISK} --script mkpart ESP fat32 1MiB 513MiB
parted ${DISK} --script set 1 esp on

# Create main partition (remaining space)
echo "→ Creating main partition..."
parted ${DISK} --script mkpart primary 513MiB 100%

# Wait for kernel to recognize partitions
sleep 2
partprobe ${DISK}
sleep 2

# Format EFI partition
echo "→ Formatting EFI partition..."
mkfs.fat -F32 ${DISK}1

# Setup LUKS encryption on main partition
echo "→ Setting up LUKS encryption..."
echo "Enter encryption passphrase:"
cryptsetup luksFormat --type luks2 ${DISK}2

echo "→ Opening encrypted partition..."
cryptsetup open ${DISK}2 cryptroot

# Create BTRFS filesystem
echo "→ Creating BTRFS filesystem..."
mkfs.btrfs -L solid-root /dev/mapper/cryptroot

# Mount and create subvolumes
echo "→ Creating BTRFS subvolumes..."
mount /dev/mapper/cryptroot /mnt

# Create subvolumes for system and home
# Using @ and @home convention for Timeshift compatibility
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home

# Unmount
umount /mnt

# Mount subvolumes in target location
echo "→ Mounting filesystems..."
mount -o subvol=@ /dev/mapper/cryptroot /target
mkdir -p /target/home
mount -o subvol=@home /dev/mapper/cryptroot /target/home
mkdir -p /target/boot/efi
mount ${DISK}1 /target/boot/efi

# Update /etc/fstab (will be done by installer, but prepare)
echo "→ Preparing fstab entries..."
cat > /tmp/fstab.btrfs <<EOF
# BTRFS root with @ subvolume
UUID=$(blkid -s UUID -o value /dev/mapper/cryptroot) / btrfs defaults,subvol=@ 0 1

# BTRFS home with @home subvolume
UUID=$(blkid -s UUID -o value /dev/mapper/cryptroot) /home btrfs defaults,subvol=@home 0 2

# EFI System Partition
UUID=$(blkid -s UUID -o value ${DISK}1) /boot/efi vfat umask=0077 0 1
EOF

echo ""
echo "================================================"
echo "BTRFS Partitioning Complete!"
echo "================================================"
echo "Layout:"
echo "  ${DISK}1: EFI System Partition (FAT32)"
echo "  ${DISK}2: LUKS encrypted BTRFS"
echo "    ├─ @ (root)"
echo "    └─ @home (home)"
echo ""
echo "Mounted at /target and ready for installation"
