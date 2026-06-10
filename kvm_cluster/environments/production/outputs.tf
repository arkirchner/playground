output "kubeconfig" {
  description = "Kubernetes configuration for cluster access"
  value       = module.cluster.kubeconfig
  sensitive   = true
}

output "talosconfig" {
  description = "Talos client configuration"
  value       = module.cluster.talosconfig
  sensitive   = true
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = module.cluster.cluster_endpoint
}

output "controlplane_nodes" {
  description = "Control plane node IPs"
  value       = module.cluster.controlplane_nodes
}

output "worker_nodes" {
  description = "Worker node IPs"
  value       = module.cluster.worker_nodes
}
