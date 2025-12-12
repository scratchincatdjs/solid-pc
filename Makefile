.PHONY: all clean clean-all download-iso verify-iso check-deps packer-build extract-iso customize-iso rebuild-iso test-iso help

# Variables
UBUNTU_VERSION = 24.04.3
UBUNTU_ISO_FLAVOR = desktop-amd64
UBUNTU_ISO_NAME = ubuntu-$(UBUNTU_VERSION)-$(UBUNTU_ISO_FLAVOR).iso
UBUNTU_ISO_PATH = downloads/$(UBUNTU_ISO_NAME)
OUTPUT_ISO = output/solid-ubuntu-$(basename $(UBUNTU_VERSION)).iso

# Colors for output
GREEN = \033[0;32m
YELLOW = \033[0;33m
RED = \033[0;31m
NC = \033[0m # No Color

# Default target
all: check-deps packer-build customize-iso rebuild-iso
	@echo "$(GREEN)✓ Build complete!$(NC)"
	@echo "$(GREEN)✓ ISO ready at: $(OUTPUT_ISO)$(NC)"

help:
	@echo "SOLID Ubuntu Cinnamon ISO Builder"
	@echo ""
	@echo "Available targets:"
	@echo "  $(GREEN)make all$(NC)             - Complete build pipeline (install deps, build VM, create ISO)"
	@echo "  $(GREEN)make download-iso$(NC)    - Download Ubuntu $(UBUNTU_VERSION) ISO"
	@echo "  $(GREEN)make verify-iso$(NC)      - Verify ISO checksums"
	@echo "  $(GREEN)make check-deps$(NC)      - Check that build dependencies are installed"
	@echo "  $(GREEN)make packer-build$(NC)    - Build VM with Packer + Ansible (Stage 1)"
	@echo "  $(GREEN)make extract-iso$(NC)     - Extract base ISO (Stage 2a)"
	@echo "  $(GREEN)make customize-iso$(NC)   - Inject customizations into ISO (Stage 2b)"
	@echo "  $(GREEN)make rebuild-iso$(NC)     - Rebuild bootable ISO (Stage 2c)"
	@echo "  $(GREEN)make test-iso$(NC)        - Test ISO in QEMU VM"
	@echo "  $(GREEN)make clean$(NC)           - Remove build artifacts (keep downloads)"
	@echo "  $(GREEN)make clean-all$(NC)       - Remove everything including downloads"

download-iso:
	@echo "$(YELLOW)→ Downloading Ubuntu $(UBUNTU_VERSION) ISO...$(NC)"
	@./scripts/download-ubuntu-iso.sh $(UBUNTU_VERSION) $(UBUNTU_ISO_FLAVOR)
	@echo "$(GREEN)✓ Download complete$(NC)"

verify-iso: download-iso
	@echo "$(YELLOW)→ Verifying ISO checksums...$(NC)"
	@./scripts/verify-iso.sh $(UBUNTU_ISO_PATH)
	@echo "$(GREEN)✓ ISO verified$(NC)"

check-deps:
	@echo "$(YELLOW)→ Checking build dependencies...$(NC)"
	@MISSING=""; \
	command -v packer &> /dev/null || MISSING="$$MISSING packer"; \
	command -v qemu-system-x86_64 &> /dev/null || MISSING="$$MISSING qemu-system-x86_64"; \
	command -v qemu-img &> /dev/null || MISSING="$$MISSING qemu-img"; \
	command -v virsh &> /dev/null || MISSING="$$MISSING virsh(libvirt)"; \
	command -v ansible &> /dev/null || MISSING="$$MISSING ansible"; \
	command -v unsquashfs &> /dev/null || MISSING="$$MISSING unsquashfs(squashfs-tools)"; \
	command -v mksquashfs &> /dev/null || MISSING="$$MISSING mksquashfs(squashfs-tools)"; \
	command -v genisoimage &> /dev/null || MISSING="$$MISSING genisoimage"; \
	command -v xorriso &> /dev/null || MISSING="$$MISSING xorriso"; \
	command -v tree &> /dev/null || MISSING="$$MISSING tree"; \
	command -v wget &> /dev/null || MISSING="$$MISSING wget"; \
	command -v curl &> /dev/null || MISSING="$$MISSING curl"; \
	if [ -n "$$MISSING" ]; then \
		echo "$(RED)✗ Missing dependencies:$$MISSING$(NC)"; \
		echo "$(YELLOW)  On Fedora, install with:$(NC)"; \
        echo "$(YELLOW)    sudo dnf install packer qemu-system-x86 qemu-img libvirt libvirt-client ansible-core \\$(NC)";
        echo "$(YELLOW)                      virt-install squashfs-tools genisoimage xorriso tree wget curl$(NC)";
		echo "$(YELLOW)  Note: Packer may require adding HashiCorp repo first:$(NC)"; \
		echo "$(YELLOW)    sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo$(NC)"; \
		exit 1; \
	fi
	@if ! groups | grep -qw libvirt; then \
		echo "$(RED)✗ User '$(USER)' is not in the libvirt group$(NC)"; \
		echo "$(YELLOW)  Add with: sudo usermod -a -G libvirt $(USER)$(NC)"; \
		echo "$(YELLOW)  Then log out and back in$(NC)"; \
		exit 1; \
	fi
	@if ! systemctl is-active --quiet libvirtd; then \
		echo "$(RED)✗ libvirtd service is not running$(NC)"; \
		echo "$(YELLOW)  Start with: sudo systemctl enable --now libvirtd$(NC)"; \
		exit 1; \
	fi
	@if [ ! -e /dev/kvm ]; then \
		echo "$(RED)✗ /dev/kvm not found — KVM acceleration unavailable$(NC)"; \
		echo "$(YELLOW)  Your system may not support virtualization or BIOS VT-x/AMD-V is disabled$(NC)"; \
		exit 1; \
	fi

	@if ! lsmod | grep -qw kvm; then \
		echo "$(RED)✗ KVM kernel module is not loaded$(NC)"; \
		echo "$(YELLOW)  Load with: sudo modprobe kvm && sudo modprobe kvm_amd  # or kvm_intel$(NC)"; \
		exit 1; \
	fi

	@if ! groups | grep -qw kvm; then \
		echo "$(RED)✗ User '$(USER)' is not in the kvm group$(NC)"; \
		echo "$(YELLOW)  Add with: sudo usermod -aG kvm $(USER)$(NC)"; \
		echo "$(YELLOW)  Then log out and back in$(NC)"; \
		exit 1; \
	fi

	@if [ ! -r /dev/kvm ] || [ ! -w /dev/kvm ]; then \
		echo "$(RED)✗ User '$(USER)' does not have permission to access /dev/kvm$(NC)"; \
		echo "$(YELLOW)  Fix with: sudo chown root:kvm /dev/kvm && sudo chmod 660 /dev/kvm$(NC)"; \
		exit 1; \
	fi

	@echo "$(GREEN)✓ All dependencies found$(NC)"

packer-build: verify-iso
	@echo "$(YELLOW)→ Building VM with Packer + Ansible (this will take 60-90 minutes)...$(NC)"
	@cd packer && packer init . && packer validate . && packer build .
	@echo "$(GREEN)✓ Packer build complete$(NC)"

extract-iso: verify-iso
	@echo "$(YELLOW)→ Extracting base ISO...$(NC)"
	@cd iso-builder && ./extract-iso.sh ../$(UBUNTU_ISO_PATH)
	@echo "$(GREEN)✓ ISO extracted$(NC)"

customize-iso: packer-build extract-iso
	@echo "$(YELLOW)→ Customizing installer and filesystem...$(NC)"
	@cd iso-builder && ./customize-installer.sh
	@echo "$(GREEN)✓ Customization complete$(NC)"

rebuild-iso: customize-iso
	@echo "$(YELLOW)→ Rebuilding bootable ISO...$(NC)"
	@cd iso-builder && ./rebuild-iso.sh
	@echo "$(GREEN)✓ ISO rebuilt$(NC)"

test-iso:
	@if [ ! -f $(OUTPUT_ISO) ]; then \
		echo "$(RED)✗ ISO not found at $(OUTPUT_ISO)$(NC)"; \
		echo "$(YELLOW)  Run 'make all' first$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)→ Testing ISO in QEMU VM...$(NC)"
	@./scripts/test-iso.sh $(OUTPUT_ISO)

clean:
	@echo "$(YELLOW)→ Cleaning build artifacts...$(NC)"
	@rm -rf packer/output
	@rm -rf iso-builder/workspace
	@rm -rf iso-builder/squashfs-root
	@rm -rf output/*.iso
	@echo "$(GREEN)✓ Clean complete$(NC)"

clean-all: clean
	@echo "$(YELLOW)→ Removing downloads...$(NC)"
	@rm -rf downloads
	@echo "$(GREEN)✓ All clean$(NC)"
