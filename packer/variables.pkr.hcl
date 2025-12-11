// Packer Variables for SOLID Ubuntu Cinnamon Build

variable "ubuntu_version" {
  type    = string
  default = "24.04.3"
  description = "Ubuntu version to build"
}

variable "ubuntu_flavor" {
  type    = string
  default = "desktop-amd64"
  description = "Ubuntu flavor (desktop-amd64, server-amd64)"
}

variable "iso_url" {
  type    = string
  default = "../downloads/ubuntu-24.04.3-desktop-amd64.iso"
  description = "Path to Ubuntu ISO"
}

variable "iso_checksum" {
  type    = string
  default = "file:../downloads/SHA256SUMS"
  description = "Checksum for ISO verification"
}

variable "vm_name" {
  type    = string
  default = "solid-ubuntu"
  description = "Name for the VM"
}

variable "vm_memory" {
  type    = number
  default = 4096
  description = "Memory in MB for the VM"
}

variable "vm_cpus" {
  type    = number
  default = 2
  description = "Number of CPUs for the VM"
}

variable "vm_disk_size" {
  type    = number
  default = 30000
  description = "Disk size in MB (30GB default)"
}

variable "ssh_username" {
  type    = string
  default = "solid"
  description = "SSH username for provisioning"
}

variable "ssh_password" {
  type    = string
  default = "temporary"
  description = "Temporary SSH password for provisioning"
  sensitive = true
}

variable "output_directory" {
  type    = string
  default = "output"
  description = "Directory for build output"
}
