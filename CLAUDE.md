# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SOLID (Small-business Optimized Linux Integrated Desktop) Personal Computer Builder is a Packer + Ansible project that creates a customized Linux Mint Cinnamon ISO for small business use. The goal is to provide a Windows-like experience with business-essential tools while maintaining vendor independence and cost efficiency.

## Project Architecture

This is a **two-stage build system**:

1. **Stage 1 (Packer + Ansible)**: Builds a customized VM using QEMU with all software and configurations
2. **Stage 2 (ISO Remastering)**: Extracts base Linux Mint ISO, injects customized filesystem, rebuilds bootable ISO

## Build System Structure

- `packer/` - Packer configuration for VM build (QEMU, preseed, provisioning scripts)
- `ansible/` - Ansible playbooks and roles for system provisioning
  - `roles/packages/` - Package installation/removal
  - `roles/cinnamon-desktop/` - Windows-like desktop customization
  - `roles/system-config/` - Printing, networking, power management, security
  - `roles/btrfs-timeshift/` - BTRFS snapshots and Timeshift configuration
  - `roles/first-boot/` - First-boot wizard setup
- `iso-builder/` - Scripts for ISO extraction, customization, and rebuilding
- `scripts/` - Helper scripts (download ISO, verify checksums, test ISO)
- `Makefile` - Build automation

## Common Commands

```bash
# Complete build from scratch (90-120 minutes)
make all

# Step-by-step build
make download-iso    # Download Linux Mint 22 ISO
make verify-iso      # Verify checksums
make packer-build    # Build VM with Packer + Ansible (60-90 min)
make extract-iso     # Extract base ISO
make customize-iso   # Inject customizations
make rebuild-iso     # Create bootable ISO
make test-iso        # Test in QEMU VM

# Cleanup
make clean           # Remove build artifacts (keep downloads)
make clean-all       # Remove everything including downloads

# Help
make help            # Show all available targets
```

## Project Context

The primary artifact is `docs/requirements.md`, which contains comprehensive functional and non-functional requirements for a business laptop system.

### Key Requirements Categories

The system must support:

1. **Email & Identity**: Professional email with domain name, multi-device sync (IMAP), calendar and contacts sync
2. **Office Productivity**: Microsoft Office-compatible document/spreadsheet/presentation editing, PDF viewing/editing, reliable printing
3. **Accounting**: Small-business bookkeeping with customer/vendor/invoice tracking, financial reporting, QuickBooks import capability
4. **File Management**: Cloud backup/sync with version history, encrypted backup, dedicated business documents folder
5. **Website**: Simple business website with easy content updates
6. **Backup & Recovery**: Automatic backups, system restore points, individual file recovery
7. **Desktop Experience**: Windows-familiar layout (taskbar, start menu), simplified settings, easy app access
8. **Hardware**: Stable Wi-Fi, printer compatibility, reliable sleep/wake behavior

### Non-Functional Requirements

- **Reliability**: Stable system that doesn't break after updates
- **Ease of Use**: Usable by users with basic computer skills
- **Maintainability**: Easy to rebuild/repair with documented steps
- **Security**: Full-disk encryption, proper access control, no unwanted remote access
- **Cost Efficiency**: Minimize subscriptions and ongoing costs
- **Compatibility**: Work smoothly with Microsoft Office formats
- **Performance**: Quick boot, responsive applications
- **Vendor Independence**: Avoid lock-in to Microsoft 365/Google Workspace
- **Offline Usability**: Fully functional when offline

## Development Approach

When implementing features for this project:

- Reference `docs/requirements.md` to ensure compliance with stated requirements
- Prioritize solutions that maintain vendor independence and avoid subscription lock-in
- Focus on Windows-familiar UX patterns to ease user transition
- Ensure offline-first functionality with cloud sync as enhancement
- Favor established, stable Linux tools over bleeding-edge solutions
- Document setup/configuration steps for maintainability (NFR-3)
