locals {
  vault_addr         = "https://vault.example.com:8200"
  vault_token        = trimspace(file("~/.vault/token"))
  vault_ca_cert_file = pathexpand("~/.vault/ca-crt")
  # It's used for the step that uploads a signed cert for the intermediate CA
  signed_int_cert_path = pathexpand("~/.vault/int-crt")
}
