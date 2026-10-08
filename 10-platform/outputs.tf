output "grafana" {
  value = {
    url      = "http://localhost:3300"
    user     = "admin"
    password = nonsensitive(random_password.grafana.result)
  }
}

output "forge" {
  value = var.enable_forge ? {
    url        = "https://localhost${var.forge_ports.https == 443 ? "" : ":${var.forge_ports.https}"}"
    user       = "admin"
    password   = nonsensitive(random_password.forge_admin[0].result)
    kubeconfig = "${local.root}/kubeconfig-forge (paste into Kubernetes > Clusters > Add Cluster)"
    modules    = "Settings: Module Library Git URL https://github.com/JLCode-tech/bnk-forge-modules.git, ref release/2.2"
  } : null
}

output "bnk_enabled" {
  value = var.enable_bnk
}

output "verify" {
  value = <<-EOT
    export KUBECONFIG=${local.kubeconfig}
    kubectl get nodes
    kubectl get pods -A | grep -i f5
    kubectl get gateway -A
    curl -I http://localhost:9080
  EOT
}
