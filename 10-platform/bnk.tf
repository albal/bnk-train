# BIG-IP Next for Kubernetes: FAR pull secrets, cert-manager CA issuer, the
# F5 Lifecycle Operator (FLO) and the CNEInstance that makes FLO deploy TMM
# and the rest of the BNK control plane.
#
# Everything here has count = 0 until enable_bnk = true. far-setup comes from
# the bnk-forge module library (JLCode-tech/bnk-forge-modules, release/2.2).
# A module source can't take a variable, so the ref is pinned in the source.
#
# OPEN ITEM for k3d: the CNEInstance references two Multus
# NetworkAttachmentDefinitions (var.network_attachments) for TMM's data
# plane. k3d has no Multus or SR-IOV. Work them out the first time BNK is
# enabled (see README "Enabling BNK").

locals {
  bnk_on = var.enable_bnk ? 1 : 0
  # Repo checkout that terraform init makes for module.far_setup. FLO's helm
  # values template is read from here instead of being vendored.
  bnk_modules_dir = "${path.module}/.terraform/modules/far_setup"
}

resource "terraform_data" "bnk_preflight" {
  count = local.bnk_on

  lifecycle {
    precondition {
      condition     = fileexists(var.far_key_path) && fileexists(var.jwt_path)
      error_message = "enable_bnk = true needs ${var.far_key_path} and ${var.jwt_path}. See ../secrets/README.md."
    }
  }
}

resource "kubernetes_namespace_v1" "flo" {
  count = local.bnk_on
  metadata {
    name = var.flo_namespace
  }
  depends_on = [terraform_data.bnk_preflight]
}

# Creates the f5-bnk and f5-utils namespaces and far-secret pull secrets,
# downloads the BNK release manifest and reads the component versions from it
module "far_setup" {
  source = "git::https://github.com/JLCode-tech/bnk-forge-modules.git//bnk/far-setup?ref=release/2.2"
  count  = local.bnk_on

  bnk_manifest_version     = var.bnk_manifest_version
  service_account_key_file = abspath(var.far_key_path)
  operator_namespace       = var.flo_namespace
  create_namespaces        = true
  cluster_name             = "bnk-lab"

  depends_on = [kubernetes_namespace_v1.flo]
}

# Self-signed root CA, then a CA ClusterIssuer that FLO uses
resource "kubectl_manifest" "selfsigned_issuer" {
  count      = local.bnk_on
  yaml_body  = <<-EOT
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: bnk-selfsigned-issuer
    spec:
      selfSigned: {}
  EOT
  depends_on = [helm_release.cert_manager]
}

resource "kubectl_manifest" "ca_certificate" {
  count      = local.bnk_on
  yaml_body  = <<-EOT
    apiVersion: cert-manager.io/v1
    kind: Certificate
    metadata:
      name: bnk-ca
      namespace: cert-manager
    spec:
      isCA: true
      commonName: bnk-ca
      secretName: bnk-ca-secret
      duration: 87600h
      privateKey:
        algorithm: RSA
        size: 2048
      issuerRef:
        name: bnk-selfsigned-issuer
        kind: ClusterIssuer
        group: cert-manager.io
  EOT
  depends_on = [kubectl_manifest.selfsigned_issuer]
}

resource "kubectl_manifest" "ca_issuer" {
  count      = local.bnk_on
  yaml_body  = <<-EOT
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: bnk-ca-cluster-issuer
    spec:
      ca:
        secretName: bnk-ca-secret
  EOT
  depends_on = [kubectl_manifest.ca_certificate]
}

resource "helm_release" "flo" {
  count      = local.bnk_on
  name       = "flo"
  repository = "oci://repo.f5.com/charts"
  chart      = "f5-lifecycle-operator"
  version    = module.far_setup[0].flo_version
  namespace  = var.flo_namespace
  wait       = true
  timeout    = 900

  values = [templatefile("${local.bnk_modules_dir}/bnk/flo/values.yaml", {
    cluster_issuer_name = "bnk-ca-cluster-issuer"
    far_secret_name     = module.far_setup[0].far_secret_name
    license_mode        = var.license_mode
    jwt_token           = trimspace(file(var.jwt_path))
    container_platform  = "Generic"
  })]

  depends_on = [module.far_setup, kubectl_manifest.ca_issuer]
}

# CNEInstance: FLO deploys CWC, DSSM, TMM, Observer, OTEL and RabbitMQ from
# it. The spec follows bnk-forge-modules bnk/cneinstance (release/2.2). That
# module needs bnk-forge's injected provider file, so it can't be called
# directly from here.
resource "kubectl_manifest" "cneinstance" {
  count = local.bnk_on
  yaml_body = yamlencode({
    apiVersion = "k8s.f5.com/v1"
    kind       = "CNEInstance"
    metadata = {
      name      = "bnk-instance"
      namespace = var.flo_namespace
    }
    spec = {
      manifestVersion = var.bnk_manifest_version
      deploymentSize  = "Small"
      product         = { type = "BNK", gatewayAPI = true }
      registry = {
        uri              = "repo.f5.com"
        imagePullPolicy  = "IfNotPresent"
        imagePullSecrets = [{ name = module.far_setup[0].far_secret_name }]
      }
      networkAttachments = var.network_attachments
      certificate        = { clusterIssuer = "bnk-ca-cluster-issuer" }
      wholeCluster       = true
      dpu                = { enabled = false }
      # FLO needs these toggles spelled out; empty objects produce an
      # incomplete TMM template
      dynamicRouting = { enabled = false }
      firewallACL    = { enabled = false }
      pseudoCNI      = { enabled = false }
      coreCollection = { enabled = false }
      intelligentLB  = { enabled = false }
      telemetry = {
        loggingSubsystem = { enabled = true }
        metricSubsystem  = { enabled = true }
      }
      advanced = {
        envDiscovery  = { enabled = false, stopOnFail = false }
        cneController = { env = [{ name = "TMM_DEFAULT_MTU", value = "1500" }] }
        tmm = {
          env = concat([
            { name = "TMM_DEFAULT_MTU", value = "1500" },
            { name = "TMM_IGNORE_GATEWAYS", value = "FALSE" },
          ], var.tmm_extra_env)
        }
      }
    }
  })

  depends_on = [helm_release.flo]
}
