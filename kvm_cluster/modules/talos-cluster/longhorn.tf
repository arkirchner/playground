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

resource "kubernetes_config_map" "longhorn_auth_proxy" {
  depends_on = [helm_release.longhorn]

  metadata {
    name      = "longhorn-auth-proxy"
    namespace = kubernetes_namespace.longhorn.metadata[0].name
  }

  data = {
    "nginx.conf" = <<-EOF
      pid /tmp/nginx.pid;
      events {}
      http {
        server {
          listen 8080;

          location / {
            auth_basic "Longhorn";
            auth_basic_user_file /etc/nginx/.htpasswd;
            proxy_pass http://longhorn-frontend:80;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          }
        }
      }
    EOF

    ".htpasswd" = "${var.admin_username}:{SHA}${var.admin_password}"
  }
}

resource "kubernetes_deployment" "longhorn_auth_proxy" {
  depends_on = [kubernetes_config_map.longhorn_auth_proxy]

  metadata {
    name      = "longhorn-auth-proxy"
    namespace = kubernetes_namespace.longhorn.metadata[0].name
    labels = {
      app = "longhorn-auth-proxy"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "longhorn-auth-proxy"
      }
    }

    template {
      metadata {
        labels = {
          app = "longhorn-auth-proxy"
        }
      }

      spec {
        security_context {
          run_as_non_root = true
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name  = "nginx"
          image = "nginxinc/nginx-unprivileged:alpine"

          port {
            container_port = 8080
          }

          security_context {
            allow_privilege_escalation = false
            run_as_non_root            = true
            capabilities {
              drop = ["ALL"]
            }
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/nginx/nginx.conf"
            sub_path   = "nginx.conf"
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/nginx/.htpasswd"
            sub_path   = ".htpasswd"
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.longhorn_auth_proxy.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "longhorn_auth_proxy" {
  depends_on = [kubernetes_deployment.longhorn_auth_proxy]

  metadata {
    name      = "longhorn-auth-proxy"
    namespace = kubernetes_namespace.longhorn.metadata[0].name
  }

  spec {
    selector = {
      app = "longhorn-auth-proxy"
    }

    port {
      port        = 80
      target_port = 8080
    }
  }
}

resource "kubectl_manifest" "longhorn_httproute" {
  depends_on = [kubernetes_service.longhorn_auth_proxy, kubectl_manifest.gateway]

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
          backendRefs = [
            {
              name = kubernetes_service.longhorn_auth_proxy.metadata[0].name
              port = 80
            }
          ]
        }
      ]
    }
  })
}
