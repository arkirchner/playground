variable "cluster_name" {
  description = "Name of the Talos cluster"
  type        = string
  default     = "production"
}

variable "talos_version" {
  description = "Talos Linux version"
  type        = string
  default     = "v1.13.3"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "v1.36.1"
}

variable "controlplane_ips" {
  description = "IP addresses for control plane nodes"
  type        = list(string)
  default     = ["10.0.0.10"]
}

variable "worker_ips" {
  description = "IP addresses for worker nodes"
  type        = list(string)
  default     = ["10.0.0.20", "10.0.0.21"]
}

variable "certificate_dns_names" {
  description = "DNS names for the TLS certificate"
  type        = list(string)
  default     = ["longhorn.test.local"]
}

variable "longhorn_host" {
  description = "Hostname for the Longhorn UI"
  type        = string
  default     = "longhorn.test.local"
}

variable "ephemeral_disk_size" {
  description = "Size of the EPHEMERAL volume on worker system disks"
  type        = string
  default     = "10GB"
}

variable "admin_username" {
  description = "Username for admin basic auth"
  type        = string
  default     = "admin"
}

variable "admin_password" {
  description = "Password for admin basic auth (SHA1 base64 hash for htpasswd)"
  type        = string
  default     = "W6ph5Mm5Pz8GgiULbPgzG37mj9g="
  sensitive   = true
}
