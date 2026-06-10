resource "talos_machine_secrets" "this" {}

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

locals {
  schematic_id     = talos_image_factory_schematic.this.id
  cluster_endpoint = "https://${var.controlplane_ips[0]}:6443"
}

data "talos_machine_configuration" "controlplane" {
  cluster_name       = var.cluster_name
  machine_type       = "controlplane"
  cluster_endpoint   = local.cluster_endpoint
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  kubernetes_version = var.kubernetes_version

  config_patches = [
    yamlencode({
      cluster = {
        allowSchedulingOnControlPlanes = length(var.worker_ips) == 0
        network = {
          cni = {
            name = "none"
          }
        }
        proxy = {
          disabled = true
        }
      }
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "NetworkRuleConfig"
      name       = "allow-ingress-http"
      portSelector = {
        ports    = [80, 443]
        protocol = "tcp"
      }
      ingress = [
        {
          subnet = "0.0.0.0/0"
        }
      ]
    })
  ]
}

data "talos_machine_configuration" "worker" {
  cluster_name       = var.cluster_name
  machine_type       = "worker"
  cluster_endpoint   = local.cluster_endpoint
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  kubernetes_version = var.kubernetes_version

  config_patches = [
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "VolumeConfig"
      name       = "EPHEMERAL"
      provisioning = {
        diskSelector = {
          match = "system_disk"
        }
        minSize = var.ephemeral_disk_size
        maxSize = var.ephemeral_disk_size
        grow    = false
      }
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "UserVolumeConfig"
      name       = "persistent-storage"
      provisioning = {
        diskSelector = {
          match = "system_disk"
        }
        minSize = "1GB"
        grow    = true
      }
    }),
    yamlencode({
      machine = {
        kubelet = {
          extraMounts = [
            {
              destination = "/var/mnt/persistent-storage"
              type        = "bind"
              source      = "/var/mnt/persistent-storage"
              options     = ["bind", "rshared", "rw"]
            }
          ]
        }
      }
    })
  ]
}


resource "talos_machine_configuration_apply" "controlplane" {
  count = length(var.controlplane_ips)

  depends_on = [var.node_dependency]

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = var.controlplane_ips[count.index]
}

resource "talos_machine_configuration_apply" "worker" {
  count = length(var.worker_ips)

  depends_on = [talos_machine_bootstrap.this, var.node_dependency]

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = var.worker_ips[count.index]
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [
    talos_machine_configuration_apply.controlplane
  ]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.controlplane_ips[0]
}

data "talos_cluster_health" "this" {
  depends_on = [
    talos_machine_bootstrap.this
  ]

  client_configuration = talos_machine_secrets.this.client_configuration

  control_plane_nodes = var.controlplane_ips
  worker_nodes        = var.worker_ips

  endpoints = [var.controlplane_ips[0]]

  timeouts = {
    read = "20m"
  }
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [data.talos_cluster_health.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.controlplane_ips[0]
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = var.controlplane_ips
  endpoints            = var.controlplane_ips
}
