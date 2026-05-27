terraform {
  required_version = ">= 1.5.0"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.5.0"
    }
    # Add your infrastructure provider
    # For this example, we use libvirt for local VMs
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7.0"
    }
  }
}

provider "talos" {}

provider "libvirt" {
  uri = "qemu:///system"
}
