// Packer configuration for SOLID Linux Mint ISO Builder
// This builds a customized Linux Mint VM using QEMU, provisioned with Ansible

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

source "qemu" "linux-mint" {
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

  // Boot Configuration
  boot_wait        = "5s"
  boot_command     = [
    "<esc><wait>",
    "linux /casper/vmlinuz ",
    "boot=casper ",
    "automatic-ubiquity ",
    "noprompt ",
    "url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg ",
    "hostname=solid-pc ",
    "locale=en_US.UTF-8 ",
    "keyboard-configuration/layoutcode=us ",
    "initrd=/casper/initrd.lz ",
    "quiet splash ---",
    "<enter>"
  ]

  // HTTP server for preseed file
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
  name = "solid-mint-build"

  sources = ["source.qemu.linux-mint"]

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
      "echo 'SOLID Linux Mint VM build complete!'",
      "echo 'VM disk ready for ISO remastering'",
      "echo '================================================'"
    ]
  }
}
