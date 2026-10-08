# Gateway API resources for the BNK data plane (lab step 4). They're gated
# on enable_bnk because without FLO nothing implements the GatewayClass and
# the Gateway would never be Programmed.

locals {
  gateway_class = "bnk-gatewayclass"
}

resource "kubectl_manifest" "gatewayclass" {
  count      = local.bnk_on
  yaml_body  = <<-EOT
    apiVersion: gateway.networking.k8s.io/v1
    kind: GatewayClass
    metadata:
      name: ${local.gateway_class}
    spec:
      controllerName: f5.com/${var.flo_namespace}-f5-cne-controller
      description: F5 BIG-IP Next for Kubernetes
  EOT
  depends_on = [kubectl_manifest.cneinstance]
}

resource "kubectl_manifest" "gateway" {
  count      = local.bnk_on
  yaml_body  = <<-EOT
    apiVersion: gateway.networking.k8s.io/v1
    kind: Gateway
    metadata:
      name: demo-gateway
      namespace: ${kubernetes_namespace_v1.demo.metadata[0].name}
    spec:
      gatewayClassName: ${local.gateway_class}
      listeners:
        - name: http
          protocol: HTTP
          port: 80
          allowedRoutes:
            namespaces:
              from: Same
  EOT
  depends_on = [kubectl_manifest.gatewayclass]
}

resource "kubectl_manifest" "httproute" {
  count      = local.bnk_on
  yaml_body  = <<-EOT
    apiVersion: gateway.networking.k8s.io/v1
    kind: HTTPRoute
    metadata:
      name: demo-route
      namespace: ${kubernetes_namespace_v1.demo.metadata[0].name}
    spec:
      parentRefs:
        - name: demo-gateway
      rules:
        - matches:
            - path:
                type: PathPrefix
                value: /
          backendRefs:
            - name: ${kubernetes_service_v1.demo.metadata[0].name}
              port: 80
  EOT
  depends_on = [kubectl_manifest.gateway]
}
