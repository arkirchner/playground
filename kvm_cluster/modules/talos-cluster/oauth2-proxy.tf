resource "kubernetes_namespace" "auth" {
  depends_on = [helm_release.cilium]

  metadata {
    name = "auth"
  }
}

resource "kubernetes_secret" "auth_proxy_htpasswd" {
  depends_on = [kubernetes_namespace.auth]

  metadata {
    name      = "auth-proxy-htpasswd"
    namespace = kubernetes_namespace.auth.metadata[0].name
  }

  data = {
    "htpasswd" = "${var.admin_username}:${bcrypt(var.admin_password)}"
  }
}

resource "kubernetes_config_map" "auth_proxy" {
  depends_on = [kubernetes_namespace.auth]

  metadata {
    name      = "auth-proxy"
    namespace = kubernetes_namespace.auth.metadata[0].name
  }

  data = {
    "default.conf" = <<-NGINX
      worker_processes auto;

      events {
          worker_connections 1024;
      }

      http {
          server {
              listen 4181;

              location / {
                  auth_basic           "Restricted";
                  auth_basic_user_file /etc/nginx/auth/htpasswd;

                  return 200;
              }
          }
      }
    NGINX
  }
}

resource "kubernetes_deployment" "auth_proxy" {
  depends_on = [kubernetes_namespace.auth, kubernetes_config_map.auth_proxy, kubernetes_secret.auth_proxy_htpasswd]

  metadata {
    name      = "auth-proxy"
    namespace = kubernetes_namespace.auth.metadata[0].name
    labels = {
      app = "auth-proxy"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "auth-proxy"
      }
    }

    template {
      metadata {
        labels = {
          app = "auth-proxy"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:alpine"

          port {
            container_port = 4181
          }

          volume_mount {
            name       = "nginx-config"
            mount_path = "/etc/nginx/nginx.conf"
            sub_path   = "default.conf"
          }

          volume_mount {
            name       = "htpasswd"
            mount_path = "/etc/nginx/auth"
            read_only  = true
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = 4181
            }
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = 4181
            }
          }
        }

        volume {
          name = "nginx-config"

          config_map {
            name = kubernetes_config_map.auth_proxy.metadata[0].name
          }
        }

        volume {
          name = "htpasswd"

          secret {
            secret_name = kubernetes_secret.auth_proxy_htpasswd.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "auth_proxy" {
  depends_on = [kubernetes_namespace.auth]

  metadata {
    name      = "auth-proxy"
    namespace = kubernetes_namespace.auth.metadata[0].name
  }

  spec {
    selector = {
      app = "auth-proxy"
    }

    port {
      port        = 4181
      target_port = 4181
    }
  }
}
