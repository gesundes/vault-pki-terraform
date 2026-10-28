# Upload already signed certificate for intermediate CA
# See readme for commands to sign the certificate
resource "vault_pki_secret_backend_intermediate_set_signed" "pki" {
  backend     = var.pki_path
  certificate = try(file(var.signed_int_cert_path), "")
}
