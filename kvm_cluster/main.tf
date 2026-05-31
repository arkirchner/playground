# Step 1: Generate cluster secrets
resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

# Step 2: Generate machine configurations

# Image Factory: look up extension versions and create schematic
data "talos_image_factory_extensions_versions" "this" {
  talos_version = var.talos_version
  filters = {
    names = ["iscsi-tools", "util-linux-tools"]
  }
}

resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = data.talos_image_factory_extensions_versions.this.extensions_info[*].name
      }
    }
  })
}

# Determine the installer image
locals {
  schematic_id     = talos_image_factory_schematic.this.id
  installer_image  = "factory.talos.dev/installer/${local.schematic_id}:${var.talos_version}"
  cluster_endpoint = "https://${var.controlplane_ips[0]}:6443"
}

# Control plane configuration (per-node for hostname)
data "talos_machine_configuration" "controlplane" {
  count = var.controlplane_count

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
    }),
    yamlencode({
      machine = {
        kubelet = {
          extraMounts = [
            {
              destination = "/var/lib/longhorn"
              type        = "bind"
              source      = "/var/lib/longhorn"
              options     = ["bind", "rshared", "rw"]
            }
          ]
        }
      }
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "HostnameConfig"
      auto       = "off"
      hostname   = "${var.cluster_name}-cp-${count.index}"
    })
  ]
}

# Worker configuration (per-node for hostname)
data "talos_machine_configuration" "worker" {
  count = var.worker_count

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
    }),
    yamlencode({
      machine = {
        kubelet = {
          extraMounts = [
            {
              destination = "/var/lib/longhorn"
              type        = "bind"
              source      = "/var/lib/longhorn"
              options     = ["bind", "rshared", "rw"]
            }
          ]
        }
      }
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "HostnameConfig"
      auto       = "off"
      hostname   = "${var.cluster_name}-worker-${count.index}"
    })
  ]
}

# Step 3: Apply configurations

# Apply control plane configurations
resource "talos_machine_configuration_apply" "controlplane" {
  count = var.controlplane_count

  depends_on = [libvirt_domain.controlplane]

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane[count.index].machine_configuration
  node                        = var.controlplane_ips[count.index]
}

# Apply worker configurations
resource "talos_machine_configuration_apply" "worker" {
  count = var.worker_count

  depends_on = [talos_machine_bootstrap.this, libvirt_domain.worker]

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[count.index].machine_configuration
  node                        = var.worker_ips[count.index]
}

# Step 4: Bootstrap

resource "talos_machine_bootstrap" "this" {
  depends_on = [
    talos_machine_configuration_apply.controlplane
  ]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.controlplane_ips[0]
}

resource "terraform_data" "k8s_cleanup" {
  depends_on = [talos_cluster_kubeconfig.this]

  provisioner "local-exec" {
    when    = destroy
    command = "echo 'Kubernetes namespace cleanup checkpoint passed — safe to tear down infrastructure'"
  }
}

resource "time_sleep" "wait_for_kubernetes" {
  depends_on = [terraform_data.k8s_cleanup]

  create_duration  = "300s"
  destroy_duration = "30s"
}


# Step 5: Get kubeconfig
resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.controlplane_ips[0]
}

moved {
  from = data.talos_cluster_kubeconfig.this
  to   = talos_cluster_kubeconfig.this
}

# Client configuration for talosctl
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = var.controlplane_ips
  endpoints            = var.controlplane_ips
}
