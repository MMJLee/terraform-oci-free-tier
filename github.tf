# --- GitHub Actions secret sync (optional, gated by enable_github) ---
# Auto-syncs OCI auth, SSH keys, Cloudflare creds, Auth0 creds, and module
# outputs (per-instance public IP as <NAME>_IP, per-database OCID as
# <KEY>_DB_OCID, vault, OS namespace) into the GitHub repo's Actions secrets.
# Caller can pass `github_secrets` for additional project-specific values.
#
# The caller still configures:
#   provider "github" {
#     owner = var.GITHUB_OWNER
#     token = var.GITHUB_TOKEN
#   }

locals {
  # Conditionally-included credentials — only added if the input is set.
  conditional_secrets = !var.enable_github ? {} : merge(
    var.oci_user_ocid != "" ? { OCI_USER_OCID = var.oci_user_ocid } : {},
    var.oci_fingerprint != "" ? { OCI_FINGERPRINT = var.oci_fingerprint } : {},
    var.oci_private_key != "" ? { OCI_PRIVATE_KEY = var.oci_private_key } : {},
    var.ssh_private_key != "" ? { SSH_PRIVATE_KEY = var.ssh_private_key } : {},
    var.ssh_public_key != "" ? { SSH_PUBLIC_KEY = var.ssh_public_key } : {},
    var.ip_address != "" ? { IP_ADDRESS = var.ip_address } : {},
    var.github_owner != "" ? { GH_OWNER = var.github_owner } : {},
    var.github_repo != "" ? { GH_REPO = var.github_repo } : {},

    var.enable_cloudflare ? {
      CLOUDFLARE_API_TOKEN = var.cloudflare_api_token
      CLOUDFLARE_ZONE_ID   = var.cloudflare_zone_id
      DOMAIN_NAME          = var.domain_name
    } : {},

    var.enable_auth0 ? {
      AUTH0_DOMAIN            = var.auth0_domain
      AUTH0_CLIENT_ID         = var.auth0_client_id
      AUTH0_CLIENT_SECRET     = var.auth0_client_secret
      AUTH0_M2M_CLIENT_ID     = var.auth0_m2m_client_id
      AUTH0_M2M_CLIENT_SECRET = var.auth0_m2m_client_secret
      AUTH0_ADMIN_USER_ID     = var.auth0_admin_user_id
    } : {},
  )

  # Infrastructure-derived secrets — always included when enable_github = true.
  # Per-instance public IP becomes <UPPERCASE_KEY>_IP (e.g., APP_IP, WORKER_IP).
  # Per-database OCID becomes <UPPERCASE_KEY>_DB_OCID (e.g., MAIN_DB_OCID).
  infra_secrets = !var.enable_github ? {} : merge(
    {
      OCI_TENANCY_OCID      = var.tenancy_ocid
      OCI_REGION            = var.region
      VAULT_OCID            = oci_kms_vault.vault.id
      VAULT_KEY_ID          = oci_kms_key.master_key.id
      VAULT_CRYPTO_ENDPOINT = oci_kms_vault.vault.crypto_endpoint
      OCI_OS_NAMESPACE      = data.oci_objectstorage_namespace.ns.namespace
    },
    { for k, inst in oci_core_instance.instance : "${upper(k)}_IP" => inst.public_ip },
    { for k, db in oci_database_autonomous_database.db : "${upper(k)}_DB_OCID" => db.id },
  )

  all_github_secrets = merge(
    local.infra_secrets,
    local.conditional_secrets,
    var.enable_github ? var.github_secrets : {},
  )
}

data "github_repository" "repo" {
  count     = var.enable_github ? 1 : 0
  full_name = "${var.github_owner}/${var.github_repo}"
}

resource "github_actions_secret" "secrets" {
  for_each        = local.all_github_secrets
  repository      = data.github_repository.repo[0].name
  secret_name     = each.key
  plaintext_value = each.value
}
