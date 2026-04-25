# --- Compute ---

output "instances" {
  value = {
    for k, inst in oci_core_instance.instance : k => {
      id         = inst.id
      public_ip  = inst.public_ip
      private_ip = inst.private_ip
    }
  }
}

output "ssh_commands" {
  value = {
    for k, inst in oci_core_instance.instance : k =>
    "ssh ${var.instances[k].app_user}@${inst.public_ip}"
  }
}

# --- Networking ---

output "vcn_id" {
  value = oci_core_vcn.vcn.id
}

output "public_subnet_id" {
  value = oci_core_subnet.public.id
}

output "private_subnet_id" {
  value = oci_core_subnet.private.id
}

# --- Load Balancer ---

output "load_balancer_ip" {
  value = var.enable_cloudflare ? [for ip in oci_load_balancer_load_balancer.lb[0].ip_address_details : ip.ip_address if ip.is_public][0] : null
}

# --- Databases ---

output "database_ids" {
  value = { for k, db in oci_database_autonomous_database.db : k => db.id }
}

output "database_admin_passwords" {
  value     = { for k, pw in random_password.db_admin : k => pw.result }
  sensitive = true
}

output "database_wallet_passwords" {
  value     = { for k, pw in random_password.db_wallet : k => pw.result }
  sensitive = true
}

output "database_connection_urls" {
  value = { for k, db in oci_database_autonomous_database.db : k => db.connection_urls }
}

output "db_region_host" {
  value = "adb.${var.region}.oraclecloud.com:1522"
}

# --- Vault ---

output "vault_id" {
  value = oci_kms_vault.vault.id
}

output "vault_crypto_endpoint" {
  value = oci_kms_vault.vault.crypto_endpoint
}

output "vault_key_id" {
  value = oci_kms_key.master_key.id
}

# --- Object Storage ---

output "os_namespace" {
  value = data.oci_objectstorage_namespace.ns.namespace
}

# --- Auth0 (only populated when enable_auth0 = true) ---

output "auth0_spa_client_id" {
  value     = var.enable_auth0 ? auth0_client.spa[0].id : null
  sensitive = true
}

output "auth0_m2m_client_id" {
  value     = var.enable_auth0 ? auth0_client.m2m[0].id : null
  sensitive = true
}

output "auth0_api_audience" {
  value = var.enable_auth0 ? auth0_resource_server.api[0].identifier : null
}
