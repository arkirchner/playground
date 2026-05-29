# outputs.tf
output "kubeconfig" {
  description = "Kubernetes configuration for cluster access"
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "talosconfig" {
  description = "Talos client configuration"
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = local.cluster_endpoint
}

output "controlplane_nodes" {
  description = "Control plane node IPs"
  value       = var.controlplane_ips
}

output "worker_nodes" {
  description = "Worker node IPs"
  value       = var.worker_ips
}
