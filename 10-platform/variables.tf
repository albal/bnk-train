# ---------------------------------------------------------------------------
# Platform
# ---------------------------------------------------------------------------
variable "cert_manager_version" {
  type    = string
  default = "v1.21.2"
}

variable "kube_prometheus_stack_version" {
  type    = string
  default = "92.1.1"
}

variable "gateway_api_version" {
  description = "Upstream Gateway API CRDs installed while BNK is disabled (FLO ships its own when enabled)"
  type        = string
  default     = "v1.6.3"
}

variable "grafana_node_port" {
  description = "Must match the k3d port mapping in 00-cluster (host 3300 -> 30300)"
  type        = number
  default     = 30300
}

# ---------------------------------------------------------------------------
# bnk-forge (Docker Compose UI)
# ---------------------------------------------------------------------------
variable "enable_forge" {
  type    = bool
  default = true
}

variable "forge_repo" {
  type    = string
  default = "https://github.com/f5devcentral/bnk-forge.git"
}

variable "forge_ref" {
  description = "Git branch/tag of bnk-forge to deploy"
  type        = string
  default     = "main"
}

variable "forge_dir" {
  description = "Where bnk-forge is cloned. Empty = <repo root>/bnk-forge"
  type        = string
  default     = ""
}

variable "forge_ports" {
  description = "Host ports for bnk-forge (bridge mode). 8000/8080 are avoided because they're in use on this host."
  type = object({
    https    = number
    http     = number
    backend  = number
    frontend = number
    mcp      = number
  })
  default = {
    https    = 443
    http     = 80
    backend  = 18000
    frontend = 18080
    mcp      = 18081
  }
}

# ---------------------------------------------------------------------------
# BIG-IP Next for Kubernetes — off until you have F5 entitlement files
# ---------------------------------------------------------------------------
variable "enable_bnk" {
  description = "Deploy FLO, CNEInstance (TMM) and BNK Gateway resources. Requires far_key_path and jwt_path."
  type        = bool
  default     = false
}

variable "far_key_path" {
  description = "FAR service account key (cne_pull_64.json, base64 — do not decode)"
  type        = string
  default     = "../secrets/far-credentials.json"
}

variable "jwt_path" {
  description = "BNK license JWT from MyF5"
  type        = string
  default     = "../secrets/bnk-license.jwt"
}


variable "bnk_manifest_version" {
  description = "BNK release manifest version in FAR (X.Y.Z-A.B.C-D.E.F)"
  type        = string
  default     = "2.2.1-3.2226.0-0.0.511"
}

variable "license_mode" {
  description = "FLO license operationMode: connected or disconnected"
  type        = string
  default     = "connected"
}

variable "flo_namespace" {
  type    = string
  default = "f5-operator"
}

variable "network_attachments" {
  description = "Multus NetworkAttachmentDefinitions for TMM's external/internal data plane (must exist before enable_bnk)"
  type        = list(string)
  default     = ["external-netdevice", "internal-netdevice"]
}

variable "tmm_extra_env" {
  description = "Extra TMM env vars (for k3d tuning when BNK is first enabled)"
  type        = list(object({ name = string, value = string }))
  default     = []
}
