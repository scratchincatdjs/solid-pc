# SOLID Linux Mint - Build Instructions

This document provides comprehensive instructions for building the SOLID Linux Mint customized ISO.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Detailed Build Process](#detailed-build-process)
4. [Build Output](#build-output)
5. [Testing the ISO](#testing-the-iso)
6. [Troubleshooting](#troubleshooting)
7. [Customization](#customization)

## Prerequisites

### System Requirements

- **Operating System**: Linux (Ubuntu 22.04+, Fedora 38+, or similar)
- **CPU**: 4+ cores (8+ recommended for faster builds)
- **RAM**: 8GB minimum (16GB recommended)
- **Disk Space**: 50GB free space minimum
- **Virtualization**: KVM support (hardware virtualization enabled in BIOS)

### Required Software

The build system will attempt to install dependencies automatically, but you may need to install some manually:

```bash
# Ubuntu/Debian/Mint
sudo apt-get install -y \
    qemu-kvm \
    libvirt-daemon-system \
    ansible \
    squashfs-tools \
    genisoimage \
    xorriso \
    isolinux \
    wget \
    curl

# Packer will be installed automatically from HashiCorp's repository
```

### User Permissions

Ensure your user is in the `kvm` and `libvirt` groups:

```bash
sudo usermod -a -G kvm,libvirt $USER
# Log out and back in for group changes to take effect
```

## Quick Start

For a complete build from scratch:

```bash
# Clone or navigate to the repository
cd solid-pc

# Run complete build (90-120 minutes)
make all
```

This will:
1. Download Linux Mint 22 Cinnamon ISO
2. Verify checksums
3. Install build dependencies (Packer, Ansible, QEMU, etc.)
4. Build customized VM with Packer + Ansible
5. Extract base ISO
6. Inject customizations
7. Rebuild bootable ISO

**Output**: `output/solid-mint-22.iso` (bootable USB image)

## Detailed Build Process

### Step 1: Download Base ISO

```bash
make download-iso
```

This downloads Linux Mint 22 Cinnamon (64-bit) from official mirrors to `downloads/`.

**Duration**: 5-10 minutes (depending on internet speed)

### Step 2: Verify ISO

```bash
make verify-iso
```

Verifies the downloaded ISO against official SHA256 checksums.

**Duration**: 1-2 minutes

### Step 3: Install Build Dependencies

```bash
make install-deps
```

Installs:
- Packer (from HashiCorp repository)
- Ansible
- QEMU/KVM
- Squashfs tools
- ISO building tools (genisoimage, xorriso)

**Duration**: 2-5 minutes

### Step 4: Build VM with Packer + Ansible

```bash
make packer-build
```

This is the longest stage. Packer will:
1. Create a QEMU VM
2. Boot Linux Mint ISO
3. Perform automated installation using preseed
4. Run initial setup script (`install-phase1.sh`)
5. Provision with Ansible:
   - Install/remove packages
   - Configure Cinnamon desktop (Windows-like)
   - Set up printing, networking, power management
   - Configure BTRFS and Timeshift
   - Install first-boot wizard
6. Clean up for imaging
7. Export VM disk

**Duration**: 60-90 minutes

**Monitoring**: Packer opens a QEMU window. You can watch the installation progress, but no interaction is needed.

### Step 5: Extract Base ISO

```bash
make extract-iso
```

Extracts the contents of the base Linux Mint ISO and the squashfs filesystem.

**Duration**: 5-10 minutes

**Output**: `iso-builder/workspace/` containing extracted ISO and filesystem

### Step 6: Customize Installer

```bash
make customize-iso
```

Injects:
- Custom BTRFS partitioning script
- SOLID branding
- Installer customizations

**Duration**: 2-5 minutes

### Step 7: Rebuild Bootable ISO

```bash
make rebuild-iso
```

Rebuilds the ISO with:
- Customized squashfs filesystem
- Updated manifests
- Hybrid boot support (UEFI + Legacy BIOS)
- USB bootable

**Duration**: 10-20 minutes

**Output**: `output/solid-mint-22.iso` + `output/sha256sum.txt`

## Build Output

### Final ISO

**File**: `output/solid-mint-22.iso`

**Size**: ~2.5-3GB (depending on customizations)

**Features**:
- Bootable from USB or DVD
- UEFI and Legacy BIOS support
- Hybrid ISO (can be dd'd to USB directly)

### Checksums

**File**: `output/sha256sum.txt`

Contains SHA256 checksum for verification.

### VM Artifacts

**Directory**: `packer/output/`

Contains the QEMU VM disk image (qcow2 format) from the Packer build.

## Testing the ISO

### Test in QEMU VM

```bash
make test-iso
```

Launches the ISO in a QEMU VM for testing:
- 4GB RAM
- 2 CPUs
- 30GB temporary test disk
- UEFI boot

**Note**: This creates a temporary test disk that is deleted after testing.

### Write to USB Drive

**WARNING**: This will erase all data on the target USB drive!

```bash
# Find your USB drive (e.g., /dev/sdb)
lsblk

# Write ISO to USB (replace /dev/sdX with your USB device)
sudo dd if=output/solid-mint-22.iso of=/dev/sdX bs=4M status=progress && sync
```

**Verification**:
```bash
# Verify write was successful
sudo dd if=/dev/sdX bs=4M count=$(stat -c%s output/solid-mint-22.iso | awk '{print int($1/4194304)+1}') | sha256sum
# Should match the checksum in output/sha256sum.txt
```

### Boot from USB

1. Insert USB drive into target machine
2. Reboot and enter boot menu (usually F12, F2, or Del)
3. Select USB drive
4. Test both:
   - Live session (boot without installing)
   - Installation process

## Troubleshooting

### Build Fails: "KVM not available"

**Cause**: Hardware virtualization not enabled or KVM not accessible.

**Solutions**:
1. Enable virtualization in BIOS (Intel VT-x or AMD-V)
2. Ensure KVM module is loaded:
   ```bash
   sudo modprobe kvm
   sudo modprobe kvm_intel  # or kvm_amd for AMD CPUs
   ```
3. Check permissions:
   ```bash
   sudo usermod -a -G kvm,libvirt $USER
   # Log out and back in
   ```

### Build Fails: "Packer timeout waiting for SSH"

**Cause**: Automated installation didn't complete, or SSH didn't start.

**Solutions**:
1. Watch the QEMU window during build to see where it's stuck
2. Check `packer/http/preseed.cfg` for errors
3. Increase timeout in `packer/linux-mint.pkr.hcl`:
   ```hcl
   ssh_timeout = "90m"  # Increase from 60m
   ```

### Build Fails: "Ansible connection timeout"

**Cause**: VM not accessible via SSH after installation.

**Solutions**:
1. Ensure SSH service is running (check `packer/scripts/install-phase1.sh`)
2. Verify network configuration in VM
3. Check firewall rules

### ISO Doesn't Boot: "No bootable device"

**Cause**: ISO not written correctly or BIOS settings incorrect.

**Solutions**:
1. Verify ISO checksum matches `output/sha256sum.txt`
2. Use `dd` instead of other tools to write USB:
   ```bash
   sudo dd if=output/solid-mint-22.iso of=/dev/sdX bs=4M oflag=sync status=progress
   ```
3. Try different USB port or drive
4. Disable Secure Boot in BIOS (may interfere with custom ISO)

### ISO Boots But Installer Crashes

**Cause**: Corrupted squashfs or missing files.

**Solutions**:
1. Rebuild ISO: `make clean && make rebuild-iso`
2. Check `iso-builder/rebuild-iso.sh` logs for errors
3. Verify squashfs was built correctly:
   ```bash
   unsquashfs -ll iso-builder/workspace/extract/casper/filesystem.squashfs | less
   ```

### Packer Build is Very Slow

**Cause**: Limited CPU/RAM or slow disk.

**Solutions**:
1. Increase VM resources in `packer/variables.pkr.hcl`:
   ```hcl
   vm_cpus   = 4  # Increase from 2
   vm_memory = 8192  # Increase from 4096
   ```
2. Use SSD instead of HDD for build
3. Close other applications to free up resources

### Out of Disk Space During Build

**Cause**: Build artifacts are large (10-20GB).

**Solutions**:
1. Free up space: `make clean`
2. Remove downloads: `make clean-all` (will re-download ISO)
3. Check disk usage:
   ```bash
   du -sh packer/output iso-builder/workspace downloads output
   ```

## Customization

### Changing Package Selection

Edit `ansible/group_vars/all.yml` to modify packages:

```yaml
# Add packages
office_packages:
  - libreoffice-writer
  - libreoffice-calc
  - your-package-here

# Remove packages
remove_packages:
  - unwanted-package
```

Then rebuild: `make packer-build`

### Customizing Desktop Appearance

Edit dconf settings in:
- `ansible/roles/cinnamon-desktop/files/00-solid-desktop.conf`
- `ansible/roles/cinnamon-desktop/files/01-solid-panel.conf`
- `ansible/roles/cinnamon-desktop/files/02-solid-theme.conf`

Then rebuild: `make packer-build`

### Changing Base Distribution

Currently configured for Linux Mint 22 Cinnamon. To change:

1. Edit `Makefile`:
   ```makefile
   MINT_VERSION = 21  # Change version
   ```

2. Update ISO URL in `packer/variables.pkr.hcl`

3. May need to adjust preseed for different versions

### Adding Custom Scripts

Place custom scripts in `packer/scripts/` and call them from:
- `packer/scripts/install-phase1.sh` (early setup)
- `packer/scripts/cleanup.sh` (pre-imaging)
- Or create new Ansible roles in `ansible/roles/`

## Build Times

Approximate durations on a modern system (Intel i7, 16GB RAM, SSD):

| Stage | Duration |
|-------|----------|
| Download ISO | 5-10 min |
| Verify ISO | 1-2 min |
| Install Dependencies | 2-5 min |
| Packer Build | 60-90 min |
| Extract ISO | 5-10 min |
| Customize ISO | 2-5 min |
| Rebuild ISO | 10-20 min |
| **Total** | **90-120 min** |

Slower systems may take 2-3 hours total.

## Clean Build

To start fresh:

```bash
# Remove all build artifacts
make clean-all

# Complete rebuild
make all
```

## Support

For issues:
1. Check this troubleshooting section
2. Review logs in `packer/` and `iso-builder/`
3. Consult `docs/requirements.md` for requirements
4. Check `.claude/plans/` for implementation plan
