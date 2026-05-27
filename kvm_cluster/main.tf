# Step 1: Generate cluster secrets
resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

# Step 2: Generate machine configurations

# Determine the installer image
locals {
  installer_image = var.schematic_id != "" ? (
    "factory.talos.dev/installer/${var.schematic_id}:${var.talos_version}"
  ) : (
    "ghcr.io/siderolabs/installer:${var.talos_version}"
  )
  cluster_endpoint = "https://${var.cluster_vip}:6443"
}

# Control plane configuration
data "talos_machine_configuration" "controlplane" {
  cluster_name       = var.cluster_name
  machine_type       = "controlplane"
  cluster_endpoint   = local.cluster_endpoint
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  kubernetes_version = var.kubernetes_version

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk  = "/dev/vda"
          image = local.installer_image
        }
      }
      cluster = {
        allowSchedulingOnControlPlanes = var.worker_count == 0
      }
    })
  ]
}

# Worker configuration
data "talos_machine_configuration" "worker" {
  cluster_name       = var.cluster_name
  machine_type       = "worker"
  cluster_endpoint   = local.cluster_endpoint
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  kubernetes_version = var.kubernetes_version

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk  = "/dev/vda"
          image = local.installer_image
        }
      }
    })
  ]
}

# Step 3: Apply configurations

# Apply control plane configurations
resource "talos_machine_configuration_apply" "controlplane" {
  count = var.controlplane_count

  depends_on = [libvirt_domain.controlplane]

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = var.controlplane_ips[count.index]

  config_patches = [
    yamlencode({
      machine = {
        network = {
          hostname = "${var.cluster_name}-cp-${count.index}"
        }
      }
    })
  ]
}

# Apply worker configurations
resource "talos_machine_configuration_apply" "worker" {
  count = var.worker_count

  depends_on = [talos_machine_bootstrap.this, libvirt_domain.worker]

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = var.worker_ips[count.index]

  config_patches = [
    yamlencode({
      machine = {
        network = {
          hostname = "${var.cluster_name}-worker-${count.index}"
        }
      }
    })
  ]
}

# Step 4: Bootstrap

resource "talos_machine_bootstrap" "this" {
  depends_on = [
    talos_machine_configuration_apply.controlplane
  ]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.controlplane_ips[0]
}

# Step 5: Get kubeconfig
data "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.controlplane_ips[0]
}

# Client configuration for talosctl
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = var.controlplane_ips
  endpoints            = var.controlplane_ips
}
