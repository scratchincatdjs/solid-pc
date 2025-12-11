#!/bin/bash
set -e

# Phase 1 Installation Script
# Runs immediately after base system installation
# Prepares system for Ansible provisioning

echo "================================================"
echo "SOLID Linux Mint - Phase 1 Setup"
echo "================================================"

# Update package lists
echo "→ Updating package lists..."
apt-get update

# Upgrade existing packages
echo "→ Upgrading installed packages..."
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install essential tools needed for Ansible
echo "→ Installing Ansible prerequisites..."
apt-get install -y \
    python3 \
    python3-pip \
    python3-apt \
    python3-venv \
    aptitude \
    software-properties-common

# Install useful utilities
echo "→ Installing build utilities..."
apt-get install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    net-tools \
    dconf-cli \
    dconf-editor

# Clean up
echo "→ Cleaning package cache..."
apt-get autoremove -y
apt-get clean

# Ensure SSH is running
echo "→ Enabling SSH service..."
systemctl enable ssh
systemctl start ssh

# Set up sudoers for build user (already done in preseed, but ensure it's correct)
echo "→ Configuring sudo access..."
if [ ! -f /etc/sudoers.d/solid ]; then
    echo "solid ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/solid
    chmod 440 /etc/sudoers.d/solid
fi

# Disable automatic updates during build (will re-enable in Ansible)
echo "→ Disabling automatic updates during build..."
systemctl stop unattended-upgrades || true
systemctl disable unattended-upgrades || true

echo "================================================"
echo "Phase 1 setup complete!"
echo "System ready for Ansible provisioning"
echo "================================================"
