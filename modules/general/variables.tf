variable "vault_addr" {
  type = string
}

variable "pki_path" {
  type    = string
  default = "pki"
}

variable "dns_zone" {
  type = string
}

variable "trusted_host_cidrs" {
  description = "Client networks as seen by Vault: on-prem and cloud VPN networks"
  type        = list(string)

  validation {
    condition = (
      length(var.trusted_host_cidrs) > 0 &&
      alltrue([
        for cidr in var.trusted_host_cidrs : can(cidrhost(cidr, 0))
      ])
    )
    error_message = "Specify at least one valid trusted CIDR."
  }
}
