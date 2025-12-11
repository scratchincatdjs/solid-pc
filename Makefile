.PHONY: all clean clean-all download-iso verify-iso install-deps packer-build extract-iso customize-iso rebuild-iso test-iso help

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
all: install-deps packer-build customize-iso rebuild-iso
	@echo "$(GREEN)✓ Build complete!$(NC)"
	@echo "$(GREEN)✓ ISO ready at: $(OUTPUT_ISO)$(NC)"

help:
	@echo "SOLID Ubuntu Cinnamon ISO Builder"
	@echo ""
	@echo "Available targets:"
	@echo "  $(GREEN)make all$(NC)             - Complete build pipeline (install deps, build VM, create ISO)"
	@echo "  $(GREEN)make download-iso$(NC)    - Download Ubuntu $(UBUNTU_VERSION) ISO"
	@echo "  $(GREEN)make verify-iso$(NC)      - Verify ISO checksums"
	@echo "  $(GREEN)make install-deps$(NC)    - Install build dependencies (Packer, Ansible, QEMU, etc.)"
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

install-deps:
	@echo "$(YELLOW)→ Installing build dependencies on Fedora 43...$(NC)"
	@if ! command -v packer &> /dev/null; then \
		echo "$(YELLOW)→ Installing Packer from HashiCorp repo...$(NC)"; \
		sudo dnf install -y dnf-plugins-core; \
		sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo; \
		sudo dnf install -y packer; \
	fi
	@echo "$(YELLOW)→ Installing QEMU, Ansible, and ISO tools...$(NC)"
	@sudo dnf install -y \
		qemu-kvm \
		qemu-img \
		libvirt \
		virt-manager \
		ansible-core \
		squashfs-tools \
		genisoimage \
		xorriso \
		syslinux \
		tree \
		wget \
		curl
	@echo "$(YELLOW)→ Enabling libvirtd service...$(NC)"
	@sudo systemctl enable --now libvirtd || true
	@echo "$(YELLOW)→ Adding user to libvirt group...$(NC)"
	@sudo usermod -a -G libvirt $(USER) || true
	@echo "$(GREEN)✓ Dependencies installed$(NC)"
	@echo "$(YELLOW)NOTE: You may need to log out and back in for group changes to take effect$(NC)"

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
