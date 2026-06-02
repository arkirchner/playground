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

variable "controlplane_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 1
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
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

variable "cluster_vip" {
  description = "Virtual IP for the cluster endpoint"
  type        = string
  default     = "10.0.0.100"
}

variable "disk_size" {
  description = "Disk size per node in bytes"
  type        = number
  default     = 21474836480
}

variable "controlplane_memory" {
  description = "Control plane RAM in MB"
  type        = number
  default     = 4096
}

variable "controlplane_vcpu" {
  description = "Control plane vCPUs"
  type        = number
  default     = 2
}

variable "worker_memory" {
  description = "Worker RAM in MB"
  type        = number
  default     = 4096
}

variable "worker_vcpu" {
  description = "Worker vCPUs"
  type        = number
  default     = 2
}

