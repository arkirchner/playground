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

output "kubernetes_client_configuration" {
  description = "Kubernetes client configuration for provider setup"
  value       = talos_cluster_kubeconfig.this.kubernetes_client_configuration
  sensitive   = true
}

output "schematic_id" {
  description = "Talos image schematic ID"
  value       = talos_image_factory_schematic.this.id
}
