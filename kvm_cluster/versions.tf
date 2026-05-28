terraform {
  required_version = ">= 1.5.0"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.5.0"
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
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }
}

provider "talos" {}

provider "libvirt" {
  uri = "qemu:///system"
}

provider "helm" {
  kubernetes {
    host                   = local.cluster_endpoint
    client_certificate     = base64decode(data.talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
    client_key             = base64decode(data.talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
    cluster_ca_certificate = base64decode(data.talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
  }
}

provider "kubernetes" {
  host                   = local.cluster_endpoint
  client_certificate     = base64decode(data.talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
  client_key             = base64decode(data.talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
  cluster_ca_certificate = base64decode(data.talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
}
