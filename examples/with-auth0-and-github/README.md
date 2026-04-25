# Example: enable Auth0 + GitHub Actions secret sync via module toggles

A complete configuration that turns on the module's optional Auth0 and GitHub
Actions secret sync features.

- **`enable_auth0 = true`** — module creates SPA + M2M clients, API resource server with admin scope, admin/user roles, a post-login action injecting email/name/roles into the JWT, and optionally auto-assigns the admin role to one user.
- **`enable_github = true`** — module syncs OCI auth, SSH keys, Cloudflare creds, Auth0 creds, and infrastructure outputs (per-instance `<NAME>_IP`, per-database `<KEY>_DB_OCID`, vault, OS namespace) into the GitHub repo's Actions secrets. Pass `github_secrets = {}` for project-specific extras.

## Prerequisites

In addition to the [module prerequisites](../../README.md#prerequisites):

- An **Auth0 tenant** with an M2M application authorized for the Auth0 Management API (scopes: `read:roles`, `create:roles`, `update:roles`, `read:actions`, `create:actions`, `update:actions`, `read:resource_servers`, `create:resource_servers`, `update:resource_servers`, `read:role_members`, `create:role_members`)
- A **GitHub personal access token** with `repo` scope

## Usage

```bash
cd examples/with-auth0-and-github
cp terraform.tfvars.example terraform.tfvars
# Fill in OCI, Cloudflare, GitHub, and Auth0 credentials
terraform init
terraform apply
```

## What you get afterward

- Your GitHub repo has every CI/CD secret it needs:
  - `OCI_*` (auth)
  - `SSH_PRIVATE_KEY`, `SSH_PUBLIC_KEY`, `IP_ADDRESS`
  - `CLOUDFLARE_*`, `DOMAIN_NAME`
  - `AUTH0_*`
  - `GH_OWNER`, `GH_REPO`
  - `<NAME>_IP` per instance (e.g., `APP_IP`)
  - `<KEY>_DB_OCID` per database (e.g., `MAIN_DB_OCID`)
  - `VAULT_OCID`, `VAULT_KEY_ID`, `VAULT_CRYPTO_ENDPOINT`, `OCI_OS_NAMESPACE`
- Auth0 has a SPA client, an M2M client, an API resource server, admin/user roles, and a post-login action

To auto-assign admin on first login: log in once, find your `user_id` in Auth0 Dashboard > User Management > Users, set `AUTH0_ADMIN_USER_ID` in `terraform.tfvars`, then `terraform apply` again.

## Notes

- `AUTH0_JWT_NAMESPACE` must match what your backend reads when validating JWTs (typically `https://<your-domain>`). The post-login action attaches `<namespace>/email`, `<namespace>/name`, and `<namespace>/roles` to access and ID tokens.
- `GITHUB_*` is a reserved prefix in Actions, so the GitHub-related secrets use the `GH_` prefix instead.
- `terraform destroy` removes every secret managed by `github_actions_secret`. Run `terraform apply` before pushing if you've just destroyed.
