resource "helm_release" "kube_router" {
  depends_on = [data.talos_cluster_health.this]

  name       = "kube-router"
  repository = "https://charts.enix.io/"
  chart      = "kube-router"
  version    = "1.10.0"
  namespace  = "kube-system"

  set {
    name  = "kubeRouter.cni.install"
    value = "true"
  }

  set {
    name  = "kubeRouter.serviceProxy.enabled"
    value = "true"
  }
}
