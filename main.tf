module "vault_mount_pki" {
  source = "./modules/vault_mount_pki"
  
  pki_path = var.pki_path
}

module "create_csr" {
  source = "./modules/create_csr"

  pki_path = var.pki_path

  count = var.create_csr ? 1 : 0
}

module "upload_signed_cert" {
  source = "./modules/upload_signed_cert"

  pki_path             = var.pki_path
  signed_int_cert_path = local.signed_int_cert_path

  count = var.upload_cert ? 1 : 0
}

module "general" {
  source = "./modules/general"

  pki_path           = var.pki_path
  vault_addr         = local.vault_addr
  dns_zone           = var.dns_zone
  trusted_host_cidrs = var.trusted_host_cidrs
}
