terraform {
  required_version = ">= 1.5.0"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.11.0"
    }
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}

provider "talos" {}

provider "libvirt" {
  uri = "qemu:///system"
}
