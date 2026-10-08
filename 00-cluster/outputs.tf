output "cluster_name" {
  value = var.cluster_name
}

output "kubeconfig_path" {
  value      = local.kubeconfig
  depends_on = [terraform_data.kubeconfig]
}

output "forge_kubeconfig_path" {
  description = "Kubeconfig to paste into bnk-forge (Kubernetes > Clusters > Add Cluster)"
  value       = local.forge_kubeconfig
  depends_on  = [terraform_data.kubeconfig]
}

output "host_ip" {
  value = local.host_ip
}
