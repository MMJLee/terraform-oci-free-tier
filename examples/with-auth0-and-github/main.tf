# Example: enable Auth0 + GitHub Actions secret sync via module toggles.
#
# The module owns the auth0 and github resources internally. Caller just sets
# enable_auth0 = true / enable_github = true and passes the inputs.

terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 7.12.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    auth0 = {
      source  = "auth0/auth0"
      version = ">= 1.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
  }
}

provider "oci" {
  tenancy_ocid = var.TENANCY_OCID
  user_ocid    = var.USER_OCID
  fingerprint  = var.FINGERPRINT
  private_key  = local.oci_private_key
  region       = var.REGION
}

provider "cloudflare" {
  api_token = var.CLOUDFLARE_API_TOKEN
}

provider "github" {
  owner = var.GITHUB_OWNER
  token = var.GITHUB_TOKEN
}

provider "auth0" {
  domain        = var.AUTH0_DOMAIN
  client_id     = var.AUTH0_M2M_CLIENT_ID
  client_secret = var.AUTH0_M2M_CLIENT_SECRET
}

module "infra" {
  source = "../.."

  tenancy_ocid   = var.TENANCY_OCID
  region         = var.REGION
  ssh_public_key = local.ssh_public_key
  project_name   = "example-app"

  instances = {
    app = {
      ocpus           = 4
      memory_gb       = 24
      block_volume_gb = 50
      behind_lb       = true
    }
  }

  databases = {
    main = { display_name = "MainDB", db_name = "MAINDB" }
  }

  bucket_name = "example-app-backups"

  # --- Cloudflare ---
  enable_cloudflare    = true
  cloudflare_api_token = var.CLOUDFLARE_API_TOKEN
  cloudflare_zone_id   = var.CLOUDFLARE_ZONE_ID
  domain_name          = var.DOMAIN_NAME
  dns_records          = [var.DOMAIN_NAME, "app"]

  # --- Auth0 ---
  enable_auth0        = true
  auth0_api_audience  = var.AUTH0_API_AUDIENCE
  auth0_jwt_namespace = var.AUTH0_JWT_NAMESPACE
  auth0_callback_urls = var.AUTH0_CALLBACK_URLS
  auth0_admin_user_id = var.AUTH0_ADMIN_USER_ID

  # --- GitHub Actions secret sync ---
  enable_github = true
  github_owner  = var.GITHUB_OWNER
  github_repo   = var.GITHUB_REPO

  # Credentials that get auto-merged into the secrets map (synced as-is)
  oci_user_ocid           = var.USER_OCID
  oci_fingerprint         = var.FINGERPRINT
  oci_private_key         = local.oci_private_key
  ssh_private_key         = local.ssh_private_key
  ip_address              = var.IP_ADDRESS
  auth0_domain            = var.AUTH0_DOMAIN
  auth0_client_id         = var.AUTH0_CLIENT_ID
  auth0_client_secret     = var.AUTH0_CLIENT_SECRET
  auth0_m2m_client_id     = var.AUTH0_M2M_CLIENT_ID
  auth0_m2m_client_secret = var.AUTH0_M2M_CLIENT_SECRET

  # Project-specific extras (merged on top of the auto-derived secrets)
  github_secrets = {
    # GOOGLE_CLIENT_ID = var.GOOGLE_CLIENT_ID
  }
}
