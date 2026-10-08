data "external" "host_ip" {
  program = ["bash", "-c", "ip=$(ip route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if($i==\"src\") print $(i+1)}'); jq -n --arg ip \"$ip\" '{ip:$ip}'"]
}

locals {
  host_ip          = var.host_ip != "" ? var.host_ip : data.external.host_ip.result.ip
  root             = abspath("${path.module}/..")
  kubeconfig       = "${local.root}/kubeconfig"
  forge_kubeconfig = "${local.root}/kubeconfig-forge"
}

resource "local_file" "k3d_config" {
  filename = "${path.module}/.generated/k3d-config.yaml"
  content = templatefile("${path.module}/k3d-config.yaml.tftpl", {
    name         = var.cluster_name
    agents       = var.agents
    image        = var.k3s_image
    api_port     = var.api_port
    http_port    = var.http_port
    https_port   = var.https_port
    grafana_port = var.grafana_port
    host_ip      = local.host_ip
  })
}

resource "terraform_data" "cluster" {
  triggers_replace = [local_file.k3d_config.content]

  input = {
    name = var.cluster_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      k3d cluster list ${var.cluster_name} >/dev/null 2>&1 || k3d cluster create --config ${local_file.k3d_config.filename} --wait
      kubectl --kubeconfig <(k3d kubeconfig get ${var.cluster_name}) wait --for=condition=Ready nodes --all --timeout=180s
    EOT
    interpreter = ["bash", "-c"]
  }

  provisioner "local-exec" {
    when        = destroy
    command     = "k3d cluster delete ${self.input.name}"
    interpreter = ["bash", "-c"]
  }
}

# Host-side kubeconfig (server https://0.0.0.0:<api_port>) and a copy that
# containers such as bnk-forge can use (server https://<host_ip>:<api_port>).
resource "terraform_data" "kubeconfig" {
  triggers_replace = [terraform_data.cluster.id]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      umask 077
      k3d kubeconfig get ${var.cluster_name} > ${local.kubeconfig}
      sed -E 's#server: https://[^:]+:${var.api_port}#server: https://${local.host_ip}:${var.api_port}#' ${local.kubeconfig} > ${local.forge_kubeconfig}
    EOT
    interpreter = ["bash", "-c"]
  }
}
