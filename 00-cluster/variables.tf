variable "cluster_name" {
  description = "k3d cluster name"
  type        = string
  default     = "bnk-lab"
}

variable "k3s_image" {
  description = "k3s node image"
  type        = string
  default     = "rancher/k3s:v1.34.12-k3s1"
}

variable "agents" {
  description = "Number of k3d agent (worker) nodes"
  type        = number
  default     = 2
}

variable "api_port" {
  description = "Host port for the Kubernetes API"
  type        = number
  default     = 6550
}

variable "http_port" {
  description = "Host port mapped to cluster LoadBalancer port 80 (Gateway HTTP listener)"
  type        = number
  default     = 9080
}

variable "https_port" {
  description = "Host port mapped to cluster LoadBalancer port 443"
  type        = number
  default     = 9443
}

variable "grafana_port" {
  description = "Host port mapped to Grafana NodePort 30300"
  type        = number
  default     = 3300
}

variable "host_ip" {
  description = "Host IP reachable from containers (bnk-forge). Empty = auto-detect from default route."
  type        = string
  default     = ""
}
