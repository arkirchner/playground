resource "kubernetes_namespace" "longhorn" {
  depends_on = [data.talos_cluster_health.this]

  metadata {
    name = "longhorn-system"

    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

resource "helm_release" "longhorn" {
  depends_on = [kubernetes_namespace.longhorn, kubectl_manifest.gateway]

  name       = "longhorn"
  repository = "https://charts.longhorn.io"
  chart      = "longhorn"
  version    = "1.12.0"
  namespace  = kubernetes_namespace.longhorn.metadata[0].name

  set {
    name  = "defaultSettings.defaultDataPath"
    value = "/var/mnt/persistent-storage"
  }

  set {
    name  = "longhornUI.replicas"
    value = "1"
  }

  set {
    name  = "httproute.enabled"
    value = "true"
  }

  set {
    name  = "httproute.parentRefs[0].name"
    value = kubectl_manifest.gateway.name
  }

  set {
    name  = "httproute.parentRefs[0].namespace"
    value = kubectl_manifest.gateway.namespace
  }

  set {
    name  = "httproute.hostnames[0]"
    value = var.longhorn_host
  }
}
