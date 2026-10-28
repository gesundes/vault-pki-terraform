# vault-pki-terraform

Configure Vault as an intermediate certificate authority (CA). Terraform enables PKI, generates a CSR for an external Root CA to sign, imports the signed certificate, and configures server certificate issuance for hosts in trusted networks. Vault and the Root CA must already exist.

## Repository structure and modules

```text
.
├── main.tf                       # Wires together the four modules
├── variables.tf                  # Input variables
├── locals.tf                     # Vault address and local file paths
├── versions.tf                   # Terraform/provider versions and Vault connection
├── outputs.tf                    # intermediate_csr — PEM CSR, or null
└── modules/
    ├── vault_mount_pki/          # PKI mount, TTLs, and deletion protection
    ├── create_csr/               # Intermediate CA key inside Vault and its CSR
    ├── upload_signed_cert/       # Signed Intermediate CA import
    └── general/                  # CA/CRL/OCSP URLs, PKI role, ACL, and AppRole
```

Each module defines resources in `main.tf` and inputs in `variables.tf`. All accept `pki_path`; `upload_signed_cert` also accepts `signed_int_cert_path`, while `general` accepts `vault_addr`, `dns_zone`, and `trusted_host_cidrs`. The root module supplies these values.

- **vault_mount_pki:** enables PKI with a default TTL of one day and a maximum of `315360000` seconds (3650 days, approximately **10 years**, despite the “5 years” comment in the code). `prevent_destroy` prevents Terraform from deleting the mount.
- **create_csr:** generates an internal EC P-256 key and a CSR with CN `COMPANY Intermediate Authority`. The private key stays in Vault; edit the module to change the CN.
- **upload_signed_cert:** reads a PEM file and submits it to `pki/intermediate/set-signed`. The file must exist before planning the import.
- **general:** creates the `network-hosts` role for EC P-256 server certificates, with default and maximum TTLs of 730 days. The DNS zone itself and its subdomains are allowed; wildcards, IP SANs, and localhost are prohibited. CN is required; CN and SANs come from the CSR. Client authentication, code signing, and email protection are not enabled.

The `network_hosts_pki` policy grants only `update` on `pki/sign/network-hosts`. AppRole is mounted at `auth/network-hosts`, with role `network-hosts` and shared RoleID `network-hosts-pki`. No SecretID is required: CIDRs restrict login and token use. Tokens are batch tokens valid for 300 seconds, without the `default` policy. Any admitted host can request a certificate for any allowed name in the zone; names are not bound to individual hosts. See the [AppRole documentation](https://developer.hashicorp.com/vault/docs/auth/approle).

## Prerequisites and connection settings

The examples require Terraform **`>= 1.15, <= 1.17`** (the upper bound is 1.17.0), the `hashicorp/vault 5.13.0` provider (downloaded by `terraform init`), Vault CLI, and OpenSSL 3.x.

Vault must be initialized, unsealed, and reachable over HTTPS. The operator token needs permissions to configure PKI, policies, and AppRole, plus `update` on `auth/token/create`: the [provider creates a child token](https://registry.terraform.io/providers/hashicorp/vault/5.13.0/docs). The procedure below assumes a new mount; reconcile existing resources with Terraform state first.

Edit `locals.tf` and prepare the files:

| Local | Current value | Purpose |
| --- | --- | --- |
| `vault_addr` | `https://vault.example.com:8200` | Vault API address; also used in certificate URLs |
| `vault_token` | Contents of `~/.vault/token` | Operator token, with surrounding whitespace trimmed |
| `vault_ca_cert_file` | `~/.vault/ca-crt` | Trusted CA PEM for verifying Vault HTTPS |
| `signed_int_cert_path` | `~/.vault/int-crt` | Signed Intermediate CA PEM and chain, produced in step 3 |

These are **locals**, not input variables: `-var` cannot override them. The provider explicitly uses these values, so exporting `VAULT_ADDR`/`VAULT_TOKEN` alone is insufficient. The CA securing Vault HTTPS may differ from the Intermediate CA being configured.

## Variables

Set these in `terraform.tfvars` or with `-var`:

| Variable | Type / default | Purpose |
| --- | --- | --- |
| `create_csr` | bool / `false` | Enables management of the CSR module |
| `upload_cert` | bool / `false` | Enables management of the signed CA import |
| `pki_path` | string / `"pki"` | PKI mount path without a leading slash |
| `dns_zone` | string / `"example.com"` | Allowed DNS zone for server certificates |
| `trusted_host_cidrs` | list(string) / `["10.71.0.0/16"]` | Client networks **as seen by Vault**, accounting for NAT/proxies; must be a nonempty list of valid CIDRs |

## Initial setup

All shell commands below are single-line Bash commands. Run Terraform from the repository root and review each plan before approving changes.

### 1. Prepare the configuration

Create `terraform.tfvars`, replacing the zone and networks with your own:

```hcl
pki_path           = "pki"
dns_zone           = "example.com"
trusted_host_cidrs = ["10.71.0.0/16"]
```
Or just update defaults of variables.
```bash
terraform init
```

The code declares no dependencies between the mount and its consuming modules: they receive a path string rather than a resource reference.

### 2. Generate the Intermediate CA CSR

```bash
terraform apply --var 'create_csr=true'
terraform output -raw intermediate_csr > intermediate.csr
```

### 3. Sign the CSR with an external Root CA

This example runs on a separate machine with existing `root-ca.crt` and `root-ca.key` PEM files. Keep the Root CA private key on that machine. Ensure the Root CA permits issuing an Intermediate CA and has enough remaining validity to cover the selected 1825 days.
You can sign using the [certstrap](https://github.com/square/certstrap) tool.

```bash
vim vault/intermediate.csr
certstrap sign --expires "10 years" --intermediate --path-length 0 --CA "root-ca" --csr ./vault/intermediate.csr "vault-int"
cat out/vault-int.crt out/root-ca.crt > vault/intermediate-chain.pem
```

Return `intermediate-chain.pem` to the Terraform machine and place it at `signed_int_cert_path`:

```bash
mkdir -p "$HOME/.vault" && cp intermediate-chain.pem "$HOME/.vault/int-crt"
```

PEM order: Intermediate CA first, then its parent CAs up to the root. The file must contain no private keys; see the import format in the [Vault PKI API](https://developer.hashicorp.com/vault/api-docs/secret/pki#import-ca-certificates-and-keys).

### 4. Import the certificate and configure access

```bash
terraform apply --var 'upload_cert=true'
terraform plan
terraform apply
```

Don't be bothered with resource deletions. Actually, provider doesn't delete them and everything will work fine.

The role uses issuer `default`, which must point to the imported Intermediate CA with its key. Check this explicitly if the mount has multiple issuers.

## Request a server certificate from a host

On a host within `trusted_host_cidrs`, place the trusted CA for Vault HTTPS at `~/.vault/ca-crt`.

Also make sure that root ca certificate is already installed at host:

```bash
vim /usr/local/share/ca-certificates/root-ca.crt
update-ca-certificates
```

Run the following in a separate Bash session, replacing the Vault address and hostname:

```bash
export VAULT_TOKEN="$(vault write -address=https://vault.example.com:8200 -field=token auth/network-hosts/login role_id=network-hosts-pki)"
openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -keyout server.key -out server.csr -subj "/CN=node01.example.com" -addext "subjectAltName=DNS:node01.example.com"
vault write -address=https://vault.example.com:8200 -format=json pki/sign/network-hosts csr=@server.csr ttl=168h > server-certificate.json
jq -er '.data | .certificate, .issuing_ca' server-certificate.json > fullchain.pem 
```

The result is a certificate PEM with its chain, `fullchain.pem`, for your service's TLS configuration. Clients must trust the Root CA. This request asks for one day of validity; the role and CA validity limit the certificate lifetime. Obtain a new token for requests after the 300-second token lifetime. This repository does not configure automatic certificate renewal.

## Subsequent changes

No state backend is configured, so state is stored locally. Preserve state and its backup outside Git; keep tokens, private keys, state/plan files, and `.terraform/` out of commits as well. The repository currently has no `.gitignore`. `prevent_destroy` protects only the PKI mount while that rule remains in the configuration; it does not protect all resources or prevent deletion through the Vault API.

The module sets CA, CRL, and OCSP URLs. Endpoint reachability and CRL/OCSP settings must be handled in Vault and the network. See the [Vault PKI guide](https://developer.hashicorp.com/vault/docs/secrets/pki) for details.
