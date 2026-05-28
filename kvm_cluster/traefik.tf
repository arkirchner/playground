resource "kubernetes_namespace_v1" "traefik" {
  metadata {
    name = "traefik"

    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }

  depends_on = [time_sleep.wait_for_kubernetes]
}

resource "helm_release" "traefik" {
  name       = "traefik"
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  namespace  = kubernetes_namespace_v1.traefik.metadata[0].name

  create_namespace = false

  depends_on = [kubernetes_namespace_v1.traefik]

  set {
    name  = "deployment.kind"
    value = "DaemonSet"
  }

  set {
    name  = "hostNetwork"
    value = "true"
  }

  set_list {
    name  = "securityContext.capabilities.add"
    value = ["NET_BIND_SERVICE"]
  }

  set {
    name  = "podSecurityContext.runAsUser"
    value = "0"
  }

  set {
    name  = "podSecurityContext.runAsGroup"
    value = "0"
  }

  set {
    name  = "podSecurityContext.runAsNonRoot"
    value = "false"
  }

  set {
    name  = "updateStrategy.rollingUpdate.maxUnavailable"
    value = "1"
  }

  set {
    name  = "updateStrategy.rollingUpdate.maxSurge"
    value = "0"
  }

  set {
    name  = "ports.web.expose.default"
    value = "true"
  }

  set {
    name  = "ports.web.port"
    value = "80"
  }

  set {
    name  = "ports.web.exposedPort"
    value = "80"
  }

  set {
    name  = "ports.websecure.expose.default"
    value = "true"
  }

  set {
    name  = "ports.websecure.port"
    value = "443"
  }

  set {
    name  = "ports.websecure.exposedPort"
    value = "443"
  }

  set {
    name  = "service.enabled"
    value = "false"
  }
}
