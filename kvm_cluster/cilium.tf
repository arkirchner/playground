locals {
  version = "1.19.4"
  # Cilium 1.19.x supports GatewayAPI v1.4.1 (Cilium 1.50.x will need v1.5.1)
  gateway_api_crd_version = "v1.4.1"
  gateway_api_crds = toset([
    "gatewayclasses",
    "gateways",
    "httproutes",
    "referencegrants",
    "grpcroutes"
  ])
}

data "http" "gateway_api_crd" {
  for_each = local.gateway_api_crds
  url      = "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${local.gateway_api_crd_version}/config/crd/standard/gateway.networking.k8s.io_${each.value}.yaml"
}

data "http" "experimental_gateway_tlsroutes_crd" {
  url      = "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${local.gateway_api_crd_version}/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml"
}

resource "kubectl_manifest" "gateway_api_crd" {
  depends_on = [data.talos_cluster_health.this]
  for_each   = local.gateway_api_crds
  yaml_body  = data.http.gateway_api_crd[each.value].response_body
}

resource "kubectl_manifest" "experimental_gateway_tlsroutes_crd" {
  depends_on = [data.talos_cluster_health.this]
  yaml_body  = data.http.experimental_gateway_tlsroutes_crd.response_body
}

resource "helm_release" "cilium" {
  depends_on = [kubectl_manifest.gateway_api_crd, kubectl_manifest.experimental_gateway_tlsroutes_crd]

  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = local.version
  namespace  = "kube-system"

  # default configuration form Talos docs

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
    value = "{CHOWN,KILL,NET_ADMIN,NET_RAW,NET_BIND_SERVICE,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}"
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
    name  = "k8sServiceHost"
    value = "localhost"
  }

  set {
    name  = "k8sServicePort"
    value = "7445"
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
}
