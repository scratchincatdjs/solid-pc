// Packer configuration for SOLID Ubuntu Cinnamon ISO Builder
// This builds a customized Ubuntu 24.04 LTS VM with Cinnamon desktop using QEMU

packer {
  required_version = ">= 1.8.0"

  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
    ansible = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

source "qemu" "ubuntu-cinnamon" {
  // VM Configuration
  vm_name          = var.vm_name
  memory           = var.vm_memory
  cpus             = var.vm_cpus
  disk_size        = var.vm_disk_size

  // ISO Configuration
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum

  // Disk and Output
  format           = "qcow2"
  disk_interface   = "virtio"
  net_device       = "virtio-net"
  output_directory = var.output_directory

  // Acceleration
  accelerator      = "kvm"

  // Boot Configuration for Ubuntu 24.04 autoinstall
  boot_wait        = "5s"
  boot_command     = [
    "<esc><wait>",
    "c<wait>",
    "linux /casper/vmlinuz ",
    "autoinstall ",
    "ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ",
    "--- <enter>",
    "initrd /casper/initrd<enter>",
    "boot<enter>"
  ]

  // HTTP server for cloud-init autoinstall (user-data, meta-data)
  http_directory   = "http"
  http_port_min    = 8000
  http_port_max    = 8100

  // SSH Configuration for provisioning
  ssh_username     = var.ssh_username
  ssh_password     = var.ssh_password
  ssh_timeout      = "60m"
  ssh_wait_timeout = "60m"

  // Headless mode (set to false for debugging)
  headless         = false

  // VNC configuration for monitoring
  vnc_bind_address = "0.0.0.0"
  vnc_port_min     = 5900
  vnc_port_max     = 5900

  // Shutdown
  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"
  shutdown_timeout = "10m"
}

build {
  name = "solid-ubuntu-build"

  sources = ["source.qemu.ubuntu-cinnamon"]

  // Phase 1: Wait for installation to complete and system to be ready
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "sudo cloud-init status --wait || true",
      "echo 'System ready for provisioning'"
    ]
    expect_disconnect = false
  }

  // Phase 2: Initial system setup
  provisioner "shell" {
    scripts = ["scripts/install-phase1.sh"]
    execute_command = "echo '${var.ssh_password}' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    expect_disconnect = true
    pause_before = "10s"
  }

  // Phase 3: Wait for system to come back after reboot (if needed)
  provisioner "shell" {
    inline = ["echo 'System reconnected, ready for Ansible provisioning'"]
    pause_before = "30s"
  }

  // Phase 4: Ansible provisioning
  provisioner "ansible" {
    playbook_file = "../ansible/playbooks/main.yml"
    user          = var.ssh_username
    extra_arguments = [
      "--extra-vars", "ansible_become_pass=${var.ssh_password}",
      "--extra-vars", "build_user=${var.ssh_username}",
      "-v"
    ]
    ansible_env_vars = [
      "ANSIBLE_HOST_KEY_CHECKING=False",
      "ANSIBLE_NOCOWS=1"
    ]
  }

  // Phase 5: Cleanup before imaging
  provisioner "shell" {
    scripts = ["scripts/cleanup.sh"]
    execute_command = "echo '${var.ssh_password}' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
  }

  // Phase 6: Final message
  provisioner "shell" {
    inline = [
      "echo '================================================'",
      "echo 'SOLID Ubuntu Cinnamon VM build complete!'",
      "echo 'VM disk ready for ISO remastering'",
      "echo '================================================'"
    ]
  }
}
