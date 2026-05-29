resource "kubernetes_namespace_v1" "longhorn_system" {
  metadata {
    name = "longhorn-system"

    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }

  depends_on = [time_sleep.wait_for_kubernetes]
}

resource "helm_release" "longhorn" {
  name       = "longhorn"
  repository = "https://charts.longhorn.io"
  chart      = "longhorn"
  namespace  = kubernetes_namespace_v1.longhorn_system.metadata[0].name

  create_namespace = false

  depends_on = [kubernetes_namespace_v1.longhorn_system]

  set {
    name  = "persistence.defaultClass"
    value = "true"
  }
}
