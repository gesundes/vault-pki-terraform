output "intermediate_csr" {
  description = "Intermediate CSR to sign with the root CA key"
  value       = try(module.create_csr[0].intermediate_csr, null)
}
