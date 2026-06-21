variable "cluster_name" {
  description = "Name of the Talos cluster"
  type        = string
}

variable "talos_version" {
  description = "Talos Linux version"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
}

variable "controlplane_ips" {
  description = "IP addresses for control plane nodes"
  type        = list(string)
}

variable "worker_ips" {
  description = "IP addresses for worker nodes"
  type        = list(string)
}

variable "certificate_dns_names" {
  description = "DNS names for the TLS certificate"
  type        = list(string)
}

variable "longhorn_host" {
  description = "Hostname for the Longhorn UI"
  type        = string
}

variable "ephemeral_disk_size" {
  description = "Size of the EPHEMERAL volume on worker system disks"
  type        = string
}

variable "node_dependency" {
  description = "Pass-through dependency to ensure VMs are created before Talos configuration is applied"
  type        = any
  default     = null
}

variable "cluster_issuer_spec" {
  description = "cert-manager ClusterIssuer spec (selfSigned for local, acme for production)"
  type        = any
}

variable "admin_username" {
  description = "Username for admin basic auth"
  type        = string
}

variable "admin_password" {
  description = "Password for admin basic auth"
  type        = string
  sensitive   = true
}