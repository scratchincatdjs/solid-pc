// Packer Variables for SOLID Linux Mint Build

variable "mint_version" {
  type    = string
  default = "22"
  description = "Linux Mint version to build"
}

variable "mint_flavor" {
  type    = string
  default = "cinnamon-64bit"
  description = "Linux Mint flavor (cinnamon-64bit, mate-64bit, xfce-64bit)"
}

variable "iso_url" {
  type    = string
  default = "../downloads/linuxmint-22-cinnamon-64bit.iso"
  description = "Path to Linux Mint ISO"
}

variable "iso_checksum" {
  type    = string
  default = "file:../downloads/sha256sum.txt"
  description = "Checksum for ISO verification"
}

variable "vm_name" {
  type    = string
  default = "solid-mint"
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
