# Here we enable a new secret engine "pki" (Public Key Infrastructure) at the given path
# Details: https://developer.hashicorp.com/vault/docs/secrets/pki
resource "vault_mount" "pki" {
  path                      = var.pki_path
  type                      = "pki"
  description               = "Intermediate CA PKI secrets engine"
  default_lease_ttl_seconds = 86400
  max_lease_ttl_seconds     = 315360000 # 5 years, less than for root CA

  lifecycle {
    prevent_destroy = true
  }
}