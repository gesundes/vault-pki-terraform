terraform {
  required_version = ">= 1.15, <= 1.17"
  required_providers {
    vault = {
      source = "hashicorp/vault"
      version = "5.13.0"
    }
  }
}

provider "vault" {
  address      = local.vault_addr
  token        = local.vault_token
  ca_cert_file = local.vault_ca_cert_file
}
