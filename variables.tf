variable "create_csr" {
  type = bool
  default = false
}

variable "upload_cert" {
  type = bool
  default = false
}

variable "pki_path" {
  type    = string
  default = "pki"
}

variable "dns_zone" {
  type    = string
  default = "example.com"
}

variable "trusted_host_cidrs" {
  description = "Client networks as seen by Vault: on-prem and cloud VPN networks"
  type        = list(string)
  default     = [ "10.71.0.0/16" ]
}
