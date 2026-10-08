locals {
  root       = abspath("${path.module}/..")
  kubeconfig = "${local.root}/kubeconfig"
}

provider "kubernetes" {
  config_path = local.kubeconfig
}

provider "kubectl" {
  config_path      = local.kubeconfig
  load_config_file = true
}

provider "helm" {
  kubernetes {
    config_path = local.kubeconfig
  }

  # F5 Artifact Registry login for the FLO OCI chart (only when BNK is enabled)
  dynamic "registry" {
    for_each = var.enable_bnk ? [1] : []
    content {
      url      = "oci://repo.f5.com"
      username = "_json_key_base64"
      password = trimspace(try(file(var.far_key_path), ""))
    }
  }
}
