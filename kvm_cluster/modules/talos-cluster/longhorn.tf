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
    value = "false"
  }
}

resource "kubectl_manifest" "longhorn_httproute" {
  depends_on = [helm_release.longhorn, kubectl_manifest.oauth2_proxy_reference_grant, kubernetes_deployment.auth_proxy]

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "longhorn"
      namespace = kubernetes_namespace.longhorn.metadata[0].name
    }
    spec = {
      parentRefs = [
        {
          name      = kubectl_manifest.gateway.name
          namespace = kubectl_manifest.gateway.namespace
          group     = "gateway.networking.k8s.io"
          kind      = "Gateway"
        }
      ]
      hostnames = [var.longhorn_host]
      rules = [
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/"
              }
            }
          ]
          filters = [
            {
              type = "ExternalAuth"
              externalAuth = {
                protocol = "HTTP"
                backendRef = {
                  name      = "auth-proxy"
                  namespace = "auth"
                  port      = 4181
                }
                http = {
                  allowedHeaders = [
                    "authorization",
                  ]
                  allowedResponseHeaders = [
                    "no-headers-allowed",
                  ]
                }
              }
            }
          ]
          backendRefs = [
            {
              name = "longhorn-frontend"
              port = 80
            }
          ]
        }
      ]
    }
  })
}

resource "kubectl_manifest" "oauth2_proxy_reference_grant" {
  depends_on = [kubernetes_namespace.auth]

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1beta1"
    kind       = "ReferenceGrant"
    metadata = {
      name      = "allow-longhorn-to-auth-proxy"
      namespace = "auth"
    }
    spec = {
      from = [
        {
          group     = "gateway.networking.k8s.io"
          kind      = "HTTPRoute"
          namespace = "longhorn-system"
        }
      ]
      to = [
        {
          group = ""
          kind  = "Service"
          name  = "auth-proxy"
        }
      ]
    }
  })
}
