# --- OCI Authentication ---

variable "tenancy_ocid" {
  type        = string
  description = "OCI tenancy OCID"
}

variable "region" {
  type        = string
  description = "OCI region (e.g., us-ashburn-1)"
}

# --- Compute ---

variable "instances" {
  type = map(object({
    ocpus            = number
    memory_gb        = number
    boot_volume_gb   = optional(number, 50)
    block_volume_gb  = optional(number, 0)
    app_port         = optional(number, 8080)
    app_user         = optional(string, "opc")
    workspace_path   = optional(string, "/var/workspace")
    extra_packages   = optional(list(string), [])
    extra_cloud_init = optional(string, "")
    behind_lb        = optional(bool, true)
  }))
  default = {
    app = {
      ocpus     = 4
      memory_gb = 24
    }
  }
  description = "Map of ARM instances to create. Total OCPUs must not exceed 4, total memory must not exceed 24GB."
}

variable "arm_shape" {
  type    = string
  default = "VM.Standard.A1.Flex"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key content for instance access"
}

# --- Databases ---

variable "databases" {
  type = map(object({
    display_name = string
    db_name      = string
  }))
  default     = {}
  description = "Map of ATP databases to create. Key is used for resource naming."
}

# --- Object Storage ---

variable "bucket_name" {
  type        = string
  default     = ""
  description = "Name for the Object Storage bucket. Empty string skips creation."
}

# --- Cloudflare (optional) ---

variable "enable_cloudflare" {
  type    = bool
  default = false
}

variable "cloudflare_api_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "cloudflare_zone_id" {
  type    = string
  default = ""
}

variable "domain_name" {
  type    = string
  default = ""
}

variable "dns_records" {
  type        = list(string)
  default     = []
  description = "DNS records to create. Use the domain itself for root, or a subdomain name (e.g., [\"example.com\", \"app\"])"
}

variable "cloudflare_ipv4" {
  description = "Cloudflare IPv4 ranges for NSG rules"
  default = [
    "173.245.48.0/20",
    "103.21.244.0/22",
    "103.22.200.0/22",
    "103.31.4.0/22",
    "141.101.64.0/18",
    "108.162.192.0/18",
    "190.93.240.0/20",
    "188.114.96.0/20",
    "197.234.240.0/22",
    "198.41.128.0/17",
    "162.158.0.0/15",
    "104.16.0.0/12",
    "172.64.0.0/13",
    "131.0.72.0/22",
  ]
}

variable "cloudflare_ipv6" {
  description = "Cloudflare IPv6 ranges for NSG rules"
  default = [
    "2400:cb00::/32",
    "2606:4700::/32",
    "2803:f800::/32",
    "2405:b500::/32",
    "2405:8100::/32",
    "2a06:98c0::/29",
    "2c0f:f248::/32",
  ]
}

# --- Auth0 (optional) ---

variable "enable_auth0" {
  type        = bool
  default     = false
  description = "Create Auth0 SPA + M2M clients, API resource server, roles, and post-login JWT action"
}

variable "auth0_api_audience" {
  type        = string
  default     = ""
  description = "Auth0 API identifier (audience claim) — e.g., https://api.example.com"
}

variable "auth0_jwt_namespace" {
  type        = string
  default     = ""
  description = "Custom-claim namespace prefix injected into JWTs by the post-login action — e.g., https://app.example.com. Must match what your backend reads."
}

variable "auth0_callback_urls" {
  type        = list(string)
  default     = []
  description = "Allowed callback / logout / web-origin URLs for the SPA client"
}

variable "auth0_admin_user_id" {
  type        = string
  default     = ""
  description = "Auth0 user_id (e.g., auth0|abc123) auto-assigned the admin role. Empty to skip."
}

variable "auth0_spa_name" {
  type    = string
  default = "SPA"
}

variable "auth0_m2m_name" {
  type    = string
  default = "Terraform (M2M)"
}

variable "auth0_api_name" {
  type    = string
  default = "API"
}

# --- GitHub Actions secret sync (optional) ---

variable "enable_github" {
  type        = bool
  default     = false
  description = "Sync OCI auth + module outputs (per-instance IPs, vault OCIDs, DB OCIDs, etc.) to GitHub Actions secrets"
}

variable "github_owner" {
  type        = string
  default     = ""
  description = "GitHub username or org that owns the repo"
}

variable "github_repo" {
  type        = string
  default     = ""
  description = "GitHub repository name"
}

variable "github_secrets" {
  type        = map(string)
  default     = {}
  sensitive   = true
  description = "Additional Actions secrets to set on top of the auto-derived ones. Keys become secret names verbatim."
}

# Inputs that get auto-merged into the GitHub Actions secrets map when enable_github = true.
# All optional — only included in the map if set.

variable "oci_user_ocid" {
  type      = string
  default   = ""
  sensitive = true
}

variable "oci_fingerprint" {
  type      = string
  default   = ""
  sensitive = true
}

variable "oci_private_key" {
  type        = string
  default     = ""
  sensitive   = true
  description = "OCI API private key contents (not a path)"
}

variable "ssh_private_key" {
  type        = string
  default     = ""
  sensitive   = true
  description = "SSH private key contents (used by CI/CD to deploy to instances). Synced as SSH_PRIVATE_KEY."
}

variable "ip_address" {
  type        = string
  default     = ""
  description = "Public IP (CIDR) of CI runner / dev machine for SSH access. Synced as IP_ADDRESS."
}

variable "auth0_domain" {
  type    = string
  default = ""
}

variable "auth0_client_id" {
  type      = string
  default   = ""
  sensitive = true
}

variable "auth0_client_secret" {
  type      = string
  default   = ""
  sensitive = true
}

variable "auth0_m2m_client_id" {
  type      = string
  default   = ""
  sensitive = true
}

variable "auth0_m2m_client_secret" {
  type      = string
  default   = ""
  sensitive = true
}

# --- Tags ---

variable "project_name" {
  type        = string
  default     = "app"
  description = "Project name used in resource display names"
}
