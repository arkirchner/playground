module "cluster" {
  source = "../../modules/talos-cluster"

  cluster_name           = var.cluster_name
  talos_version          = var.talos_version
  kubernetes_version     = var.kubernetes_version
  controlplane_ips       = var.controlplane_ips
  worker_ips             = var.worker_ips
  certificate_dns_names  = var.certificate_dns_names
  longhorn_host          = var.longhorn_host
  ephemeral_disk_size    = var.ephemeral_disk_size
  admin_username         = var.admin_username
  admin_password         = var.admin_password
  cluster_issuer_spec = {
    acme = {
      server = "https://acme-v02.api.letsencrypt.org/directory"
      privateKeySecretRef = {
        name = "letsencrypt-issuer-key"
      }
      solvers = [
        {
          http01 = {
            gatewayHTTPRoute = {
              parentRefs = [
                {
                  name      = "cilium"
                  namespace = "kube-system"
                  kind      = "Gateway"
                }
              ]
            }
          }
        }
      ]
    }
  }
}

provider "helm" {
  kubernetes {
    host                   = module.cluster.cluster_endpoint
    client_certificate     = base64decode(module.cluster.kubernetes_client_configuration.client_certificate)
    client_key             = base64decode(module.cluster.kubernetes_client_configuration.client_key)
    cluster_ca_certificate = base64decode(module.cluster.kubernetes_client_configuration.ca_certificate)
  }
}

provider "kubernetes" {
  host                   = module.cluster.cluster_endpoint
  client_certificate     = base64decode(module.cluster.kubernetes_client_configuration.client_certificate)
  client_key             = base64decode(module.cluster.kubernetes_client_configuration.client_key)
  cluster_ca_certificate = base64decode(module.cluster.kubernetes_client_configuration.ca_certificate)
}

provider "kubectl" {
  host                   = module.cluster.cluster_endpoint
  client_certificate     = base64decode(module.cluster.kubernetes_client_configuration.client_certificate)
  client_key             = base64decode(module.cluster.kubernetes_client_configuration.client_key)
  cluster_ca_certificate = base64decode(module.cluster.kubernetes_client_configuration.ca_certificate)
  load_config_file       = false
}
