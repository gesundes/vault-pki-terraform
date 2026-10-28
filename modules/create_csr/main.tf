# Make a request to sign an intermediate CA with the offline root CA key
resource "vault_pki_secret_backend_intermediate_cert_request" "pki" {
  backend     = var.pki_path
  type        = "internal"
  common_name = "COMPANY Intermediate Authority"
  key_type    = "ec"
  key_bits    = 256
}

output "intermediate_csr" {
  value = vault_pki_secret_backend_intermediate_cert_request.pki.csr
}
