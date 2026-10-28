# Create endpoints needed for pki real work
resource "vault_pki_secret_backend_config_urls" "pki" {
  backend = var.pki_path

  issuing_certificates = [
    "${var.vault_addr}/v1/${var.pki_path}/ca",
  ]

  crl_distribution_points = [
    "${var.vault_addr}/v1/${var.pki_path}/crl",
  ]

  ocsp_servers = [
    "${var.vault_addr}/v1/${var.pki_path}/ocsp",
  ]
}

# Create a role for the pki that sets a lot of defaults for certificate issuer
# It allows to sign certs only for definde domain zone (allowed_domains option)
# But it's not for users authorization and applying restrictions
resource "vault_pki_secret_backend_role" "network_hosts" {
  backend    = var.pki_path
  name       = "network-hosts"
  
  issuer_ref = "default"

  ttl     = 63072000
  max_ttl = 63072000

  allowed_domains             = [var.dns_zone]
  allow_bare_domains          = true
  allow_subdomains            = true
  allow_glob_domains          = false
  allow_wildcard_certificates = false
  allow_any_name              = false
  allow_localhost             = false
  allow_ip_sans               = false

  enforce_hostnames = true

  server_flag           = true
  client_flag           = false
  code_signing_flag     = false
  email_protection_flag = false

  key_type = "ec"
  key_bits = 256

  use_csr_common_name = true
  use_csr_sans        = true
  require_cn          = true
}

# Set a policy that defines capabilities for a specific role ("network-hosts")
resource "vault_policy" "network_hosts_pki" {
  name = "network_hosts_pki"

  policy = <<-EOT
    path "${var.pki_path}/sign/network-hosts" {
      capabilities = ["update"]
    }
  EOT
}

# Here and below we configure auth backend to grant access to all hosts in a specific network
resource "vault_auth_backend" "network_hosts" {
  type        = "approle"
  path        = "network-hosts"
  description = "PKI access for hosts in trusted networks"
}

resource "vault_approle_auth_backend_role" "network_hosts" {
  backend   = vault_auth_backend.network_hosts.path
  role_name = "network-hosts"

  # Shared identifier, not a per-host credential.
  role_id = "network-hosts-pki"

  # Network membership is the authentication boundary.
  bind_secret_id = false

  # Restrict login requests.
  secret_id_bound_cidrs = var.trusted_host_cidrs

  # Restrict use of the resulting tokens.
  token_bound_cidrs = var.trusted_host_cidrs

  token_policies = [
    vault_policy.network_hosts_pki.name,
  ]

  token_no_default_policy = true

  token_type             = "batch"
  token_ttl              = 300
  token_max_ttl          = 300
  token_explicit_max_ttl = 300
}
