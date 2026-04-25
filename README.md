# terraform-oci-free-tier

Reusable Terraform module for OCI Always Free tier infrastructure. Deploys ARM compute instances, Oracle Autonomous Databases, and OCI Vault KMS, with optional toggles for a Cloudflare-backed load balancer + SSL, an Auth0 application stack (clients, roles, post-login JWT action), and automatic GitHub Actions secret sync of every credential and infrastructure OCID a CI pipeline needs.

## What it creates

- **Networking** — VCN, public/private subnets, internet + service gateways, route tables
- **Compute** — 1+ ARM A1.Flex instances with per-instance cloud-init, optional block volumes
- **Database** — 0-2 ATP free-tier instances (23ai) with auto-generated passwords stored in Vault
- **Vault** — OCI Vault + AES-256 master key + dynamic group + IAM policies for instance principal auth
- **Object Storage** — Optional Object Storage bucket with prevent_destroy lifecycle
- **Security** — Public/private security lists, SSH access, per-instance app port ingress
- **Quota** — Free tier enforcement (4 ARM OCPUs, 2 AMD micros, 200GB storage)
- **Cloudflare** (optional) — Load balancer, origin CA certificate, DNS records, strict SSL
- **Auth0** (optional) — SPA + M2M clients, API resource server with admin scope, admin/user roles, post-login JWT action
- **GitHub Actions secret sync** (optional) — auto-pushes OCI auth, SSH keys, Cloudflare/Auth0 creds, and infrastructure outputs (per-instance `<NAME>_IP`, per-database `<KEY>_DB_OCID`, vault, OS namespace) into a GitHub repo's Actions secrets

## Prerequisites

- [Terraform](https://terraform.io) >= 1.10
- OCI account (Pay As You Go — all resources stay within Always Free tier)
- `~/.oci/config` configured for local OCI auth ([setup guide](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/apisigningkey.htm))
- Cloudflare account with a domain (only if using `enable_cloudflare = true`)

## Getting Started

```bash
# 1. In your project's terraform directory, create main.tf with the module call (see examples below)
# 2. Configure providers (OCI + optionally Cloudflare)
# 3. Create terraform.tfvars with your credentials
# 4. Run:
terraform init
terraform plan    # review what will be created
terraform apply   # deploy (confirm with 'yes')

# 5. After deploy:
terraform output                                   # see IPs, DB info, SSH commands
terraform output -json ssh_commands                # all SSH commands (map)
terraform output -raw arm_instance_public_ip 2>/dev/null \
  || terraform output -json instances | jq -r '.app.public_ip'  # one instance's IP
```

## Usage

### Single instance (simple)

```hcl
module "infra" {
  source = "github.com/MMJLee/terraform-oci-free-tier"

  tenancy_ocid = var.TENANCY_OCID
  region       = var.REGION
  ssh_public_key = file("./id_rsa.pub")
  project_name   = "myapp"

  instances = {
    app = {
      ocpus            = 4
      memory_gb        = 24
      block_volume_gb  = 50
      extra_packages   = ["nodejs:20"]
      extra_cloud_init = "npm install -g some-cli || true"
    }
  }

  databases = {
    main = { display_name = "MainDB", db_name = "MAINDB" }
  }

  enable_cloudflare    = true
  cloudflare_api_token = var.CLOUDFLARE_API_TOKEN
  cloudflare_zone_id   = var.CLOUDFLARE_ZONE_ID
  domain_name          = "example.com"
  dns_records          = ["example.com", "app"]
}
```

### Multiple instances (split free tier)

```hcl
module "infra" {
  source = "github.com/MMJLee/terraform-oci-free-tier"

  tenancy_ocid   = var.TENANCY_OCID
  region         = var.REGION
  ssh_public_key = file("./id_rsa.pub")
  project_name   = "platform"

  instances = {
    api = {
      ocpus            = 2
      memory_gb        = 12
      block_volume_gb  = 50
      app_port         = 8080
      extra_packages   = ["nodejs:20"]
      behind_lb        = true
    }
    worker = {
      ocpus            = 1
      memory_gb        = 6
      block_volume_gb  = 50
      app_port         = 9090
      extra_packages   = ["python3"]
      behind_lb        = false
    }
    agent = {
      ocpus            = 1
      memory_gb        = 6
      app_port         = 8081
      extra_cloud_init = "npm install -g @anthropic-ai/claude-code || true"
      behind_lb        = false
    }
  }

  databases = {
    main  = { display_name = "MainDB",  db_name = "MAINDB" }
    agent = { display_name = "AgentDB", db_name = "AGENTDB" }
  }

  bucket_name = "platform-backups"

  enable_cloudflare    = true
  cloudflare_api_token = var.CLOUDFLARE_API_TOKEN
  cloudflare_zone_id   = var.CLOUDFLARE_ZONE_ID
  domain_name          = "example.com"
  dns_records          = ["example.com", "api"]
}
```

### With Auth0 + GitHub Actions secret sync

Both features live inside the module — flip `enable_auth0 = true` and/or `enable_github = true`, pass the inputs.

```hcl
module "infra" {
  source = "github.com/MMJLee/terraform-oci-free-tier"

  tenancy_ocid   = var.TENANCY_OCID
  region         = var.REGION
  ssh_public_key = file("./id_rsa.pub")
  project_name   = "myapp"

  instances = { app = { ocpus = 4, memory_gb = 24 } }
  databases = { main = { display_name = "MainDB", db_name = "MAINDB" } }

  enable_cloudflare    = true
  cloudflare_api_token = var.CLOUDFLARE_API_TOKEN
  cloudflare_zone_id   = var.CLOUDFLARE_ZONE_ID
  domain_name          = "example.com"
  dns_records          = ["example.com", "app"]

  # Auth0
  enable_auth0        = true
  auth0_api_audience  = "https://api.example.com"
  auth0_jwt_namespace = "https://app.example.com" # must match what your backend reads
  auth0_callback_urls = ["https://app.example.com", "http://localhost:5173"]
  auth0_admin_user_id = "auth0|abc123" # optional; auto-assigns admin role

  # GitHub Actions secret sync — also forwards OCI/Cloudflare/Auth0 creds
  enable_github           = true
  github_owner            = "your-username"
  github_repo             = "your-repo"
  oci_user_ocid           = var.USER_OCID
  oci_fingerprint         = var.FINGERPRINT
  oci_private_key         = file(var.OCI_PRIVATE_KEY_PATH)
  ssh_private_key         = file(var.SSH_PRIVATE_KEY_PATH)
  ip_address              = var.IP_ADDRESS
  auth0_domain            = var.AUTH0_DOMAIN
  auth0_client_id         = var.AUTH0_CLIENT_ID
  auth0_client_secret     = var.AUTH0_CLIENT_SECRET
  auth0_m2m_client_id     = var.AUTH0_M2M_CLIENT_ID
  auth0_m2m_client_secret = var.AUTH0_M2M_CLIENT_SECRET

  # Caller-provided extras (merged on top of auto-derived secrets)
  github_secrets = {
    GOOGLE_CLIENT_ID = var.GOOGLE_CLIENT_ID
  }
}
```

See [`examples/with-auth0-and-github/`](examples/with-auth0-and-github/) for the full working example with providers, variables, and tfvars.

## Providers

The calling module must configure providers for everything it has enabled:

```hcl
provider "oci" {
  tenancy_ocid = var.TENANCY_OCID
  user_ocid    = var.USER_OCID
  fingerprint  = var.FINGERPRINT
  private_key  = file(var.OCI_PRIVATE_KEY_PATH)
  region       = var.REGION
}

# Only needed if enable_cloudflare = true
provider "cloudflare" {
  api_token = var.CLOUDFLARE_API_TOKEN
}

# Only needed if enable_auth0 = true
provider "auth0" {
  domain        = var.AUTH0_DOMAIN
  client_id     = var.AUTH0_M2M_CLIENT_ID
  client_secret = var.AUTH0_M2M_CLIENT_SECRET
}

# Only needed if enable_github = true
provider "github" {
  owner = var.GITHUB_OWNER
  token = var.GITHUB_TOKEN
}
```

## Instance Configuration

Each instance in the `instances` map accepts:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `ocpus` | number | required | ARM OCPUs for this instance |
| `memory_gb` | number | required | Memory in GB |
| `boot_volume_gb` | number | `50` | Boot volume size |
| `block_volume_gb` | number | `0` | Block volume size (0 = none) |
| `app_port` | number | `8080` | Application port |
| `app_user` | string | `"opc"` | OS user for the app |
| `workspace_path` | string | `"/var/workspace"` | Block volume mount path |
| `extra_packages` | list(string) | `[]` | Additional dnf packages |
| `extra_cloud_init` | string | `""` | Additional cloud-init commands |
| `behind_lb` | bool | `true` | Include in load balancer backend |

**Free tier limits:** Total OCPUs across all instances must not exceed 4. Total memory must not exceed 24GB.

## Auth0 Configuration (`enable_auth0 = true`)

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `auth0_api_audience` | string | `""` | Auth0 API identifier (audience claim), e.g. `https://api.example.com` |
| `auth0_jwt_namespace` | string | `""` | Custom-claim namespace prefix injected into JWTs by the post-login action. **Must match what your backend reads.** |
| `auth0_callback_urls` | list(string) | `[]` | Allowed callback / logout / web-origin URLs for the SPA client |
| `auth0_admin_user_id` | string | `""` | Auth0 user_id (e.g., `auth0\|abc123`) auto-assigned the `admin` role. Empty to skip. |
| `auth0_spa_name` | string | `"SPA"` | Display name for the SPA client |
| `auth0_m2m_name` | string | `"Terraform (M2M)"` | Display name for the M2M client |
| `auth0_api_name` | string | `"API"` | Display name for the API resource server |

The post-login action requires verified email and injects `<namespace>/email`, `<namespace>/name`, and `<namespace>/roles` into both access and ID tokens. Two roles are created: `admin` (with `admin:access` scope on the API) and `user`.

## GitHub Secret Sync Configuration (`enable_github = true`)

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `github_owner` | string | `""` | GitHub username or org that owns the repo |
| `github_repo` | string | `""` | GitHub repository name |
| `github_secrets` | map(string) | `{}` | Additional Actions secrets to set on top of the auto-derived ones. Keys become secret names verbatim. |
| `oci_user_ocid` | string (sensitive) | `""` | Synced as `OCI_USER_OCID` |
| `oci_fingerprint` | string (sensitive) | `""` | Synced as `OCI_FINGERPRINT` |
| `oci_private_key` | string (sensitive) | `""` | OCI API private key contents. Synced as `OCI_PRIVATE_KEY`. |
| `ssh_private_key` | string (sensitive) | `""` | SSH private key contents. Synced as `SSH_PRIVATE_KEY`. |
| `ip_address` | string | `""` | Public IP (CIDR) of CI runner / dev machine. Synced as `IP_ADDRESS`. |
| `auth0_domain` / `auth0_client_id` / `auth0_client_secret` / `auth0_m2m_client_id` / `auth0_m2m_client_secret` | string | `""` | Synced as the matching uppercase secret names (only when `enable_auth0 = true`). |

**Auto-derived secrets** (always set when `enable_github = true`):

| Secret | Source |
|--------|--------|
| `OCI_TENANCY_OCID` | `var.tenancy_ocid` |
| `OCI_REGION` | `var.region` |
| `<NAME>_IP` | one per instance, e.g. `APP_IP`, `WORKER_IP` |
| `<KEY>_DB_OCID` | one per database, e.g. `MAIN_DB_OCID`, `AGENT_DB_OCID` |
| `VAULT_OCID` / `VAULT_KEY_ID` / `VAULT_CRYPTO_ENDPOINT` | OCI Vault outputs |
| `OCI_OS_NAMESPACE` | Object Storage namespace |
| `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ZONE_ID` / `DOMAIN_NAME` | only when `enable_cloudflare = true` |
| `GH_OWNER` / `GH_REPO` | from `github_owner` / `github_repo` (`GITHUB_*` is reserved by Actions) |

## Outputs

| Name | Description |
|------|-------------|
| `instances` | Map of instance IDs, public IPs, private IPs |
| `ssh_commands` | Map of SSH commands per instance |
| `vcn_id` | VCN OCID |
| `public_subnet_id` | Public subnet OCID |
| `private_subnet_id` | Private subnet OCID |
| `load_balancer_ip` | LB public IP (null if Cloudflare disabled) |
| `database_ids` | Map of database OCIDs |
| `database_admin_passwords` | Map of DB admin passwords (sensitive) |
| `database_wallet_passwords` | Map of DB wallet passwords (sensitive) |
| `database_connection_urls` | Map of DB connection URLs |
| `db_region_host` | ATP host with port |
| `vault_id` | Vault OCID |
| `vault_crypto_endpoint` | Vault crypto endpoint |
| `vault_key_id` | Master encryption key OCID |
| `os_namespace` | Object Storage namespace |
| `auth0_spa_client_id` | Auth0 SPA client ID (null unless `enable_auth0 = true`, sensitive) |
| `auth0_m2m_client_id` | Auth0 M2M client ID (null unless `enable_auth0 = true`, sensitive) |
| `auth0_api_audience` | Auth0 API resource server identifier (null unless `enable_auth0 = true`) |

## Free Tier Limits

| Resource | Spec |
|----------|------|
| ARM Instances | 4 OCPU / 24GB total (split across instances) |
| Boot + Block Volume | 200GB total |
| Load Balancer | 1 flexible, 10 Mbps |
| Autonomous DB | 2 instances, 20GB each |
| OCI Vault | 20 key versions, 150 secrets |
| Object Storage | 10GB |
