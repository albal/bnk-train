# ---------------------------------------------------------------------------
# cert-manager — FLO needs it for its webhook/TLS certificates
# ---------------------------------------------------------------------------
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_version
  namespace        = "cert-manager"
  create_namespace = true
  wait             = true

  set {
    name  = "crds.enabled"
    value = "true"
  }
}

# ---------------------------------------------------------------------------
# Gateway API CRDs — only while BNK is off. FLO installs and owns its own
# Gateway API CRDs; there's no destroy step here, so switching enable_bnk on
# leaves the CRDs in place for FLO to adopt.
# ---------------------------------------------------------------------------
resource "terraform_data" "gateway_api_crds" {
  count            = var.enable_bnk ? 0 : 1
  triggers_replace = [var.gateway_api_version]

  provisioner "local-exec" {
    command = "kubectl --kubeconfig ${local.kubeconfig} apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.gateway_api_version}/standard-install.yaml"
  }
}

# ---------------------------------------------------------------------------
# Prometheus + Grafana
# ---------------------------------------------------------------------------
resource "random_password" "grafana" {
  length  = 20
  special = false
}

resource "helm_release" "monitoring" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.kube_prometheus_stack_version
  namespace        = "monitoring"
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [yamlencode({
    grafana = {
      adminPassword = random_password.grafana.result
      service = {
        type     = "NodePort"
        nodePort = var.grafana_node_port
      }
    }
    prometheus = {
      prometheusSpec = {
        # Pick up ServiceMonitors/PodMonitors from any namespace (e.g. BNK's)
        serviceMonitorSelectorNilUsesHelmValues = false
        podMonitorSelectorNilUsesHelmValues     = false
        retention                               = "2d"
      }
    }
    # k3s runs these inside the server process; scraping them only produces alerts
    kubeEtcd              = { enabled = false }
    kubeControllerManager = { enabled = false }
    kubeScheduler         = { enabled = false }
    kubeProxy             = { enabled = false }
  })]
}
