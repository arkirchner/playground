resource "helm_release" "cilium" {
  depends_on = [data.talos_cluster_health.this]

  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = "1.19.4"
  namespace  = "kube-system"

  set {
    name  = "ipam.mode"
    value = "kubernetes"
  }

  set {
    name  = "kubeProxyReplacement"
    value = "true"
  }

  set {
    name  = "securityContext.capabilities.ciliumAgent"
    value = "{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}"
  }

  set {
    name  = "securityContext.capabilities.cleanCiliumState"
    value = "{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}"
  }

  set {
    name  = "cgroup.autoMount.enabled"
    value = "false"
  }

  set {
    name  = "cgroup.hostRoot"
    value = "/sys/fs/cgroup"
  }

  set {
    name  = "gatewayAPI.enabled"
    value = "true"
  }
  set {
    name  = "gatewayAPI.enableAlpn"
    value = "true"
  }

  set {
    name  = "gatewayAPI.enableAppProtocol"
    value = "true"
  }

  # Allow envy to bing privileged port 80 and 443 for external traffic.
  set {
    name  = "envoy.securityContext.capabilities.keepNetBindService"
    value = "true"
  }

  set_list {
    name  = "envoy.securityContext.capabilities.envoy"
    value = ["NET_ADMIN", "SYS_ADMIN", "NET_BIND_SERVICE"]
  }

  # Expose port 80 and 443 on worker nodes

  set {
    name = "ingressController.enabled"
    value = "true"
  }

  set {
    name = "ingressController.default"
    value = "true"
  }

  set {
    name = "ingressController.hostNetwork.enabled"
    value = "true"
  }

  set {
    name = "ingressController.loadbalancerMode"
    value = "shared"
  }

  set {
    name = "ingressController.service.type"
    value = "ClusterIP"
  }
}
