# Role: ca

> Create and Manage Self-Signed Certificate Authority

| **Module**        | [INFRA](https://pigsty.io/docs/infra)    |
|-------------------|------------------------------------------|
| **Docs**          | https://pigsty.io/docs/infra/cert        |
| **Related Roles** | [`infra`](../infra), [`pgsql`](../pgsql) |


## Overview

The `ca` role creates a **self-signed Certificate Authority (CA)** for Pigsty:

- Generate CA private key (`files/pki/ca/ca.key`)
- Generate CA certificate (`files/pki/ca/ca.crt`)
- Create PKI directory structure for all modules

The CA is used to sign certificates for:
- PostgreSQL server/client SSL
- Patroni REST API
- etcd cluster communication
- MinIO cluster communication
- Nginx HTTPS (self-signed fallback)
- Infrastructure services
- FerretDB/MongoDB TLS


## Playbooks

| Playbook                       | Description                              |
|--------------------------------|------------------------------------------|
| [`infra.yml`](../../infra.yml) | Infrastructure deployment (includes CA)  |
| [`cert.yml`](../../cert.yml)   | Issue additional certificates with CA    |


## File Structure

```
roles/ca/
├── defaults/
│   └── main.yml              # Default variables
├── meta/
│   └── main.yml              # Role dependencies
└── tasks/
    └── main.yml              # CA creation logic
```


## Tags

### Tag Hierarchy

```
ca (full role)
│
├── ca_dir                     # Create PKI directories
│
├── ca_private                 # Generate CA private key
│
└── ca_cert                    # Self-sign CA certificate
```


### Tag Usage Examples

```bash
# Run the full CA role
./infra.yml -t ca

# Only create PKI directory structure
./infra.yml -t ca_dir

# Only generate CA private key (if not exists)
./infra.yml -t ca_private

# Only generate CA certificate (if not exists)
./infra.yml -t ca_cert
```


## Variables

| Variable         | Default      | Description                                |
|------------------|--------------|--------------------------------------------|
| `ca_create`      | `true`       | Create CA if not exists, or abort          |
| `ca_cn`          | `pigsty-ca`  | CA certificate common name                 |
| `cert_validity`  | `7300d`      | Default validity for issued certificates   |

### ca_create

Controls CA creation behavior:

- `true` (default): Create new CA if `files/pki/ca/ca.key` doesn't exist
- `false`: Abort if CA files don't exist (use external CA)

### ca_cn

The Common Name (CN) embedded in the CA certificate. Default is `pigsty-ca`.

### cert_validity

Default validity period for certificates signed by this CA. Used by other roles (pgsql, etcd, minio, etc.) when issuing server certificates.


## PKI Directory Structure

The CA role creates the following directory structure under `files/pki/`:

```
files/pki/
├── ca/
│   ├── ca.key                # CA private key (mode: 0600, keep secure!)
│   └── ca.crt                # CA certificate (mode: 0644)
├── csr/
│   └── *.csr                 # Certificate signing requests (temporary)
├── misc/
│   └── *.crt, *.key          # Miscellaneous certificates (cert.yml output)
├── etcd/
│   └── *.crt, *.key          # ETCD server certificates
├── pgsql/
│   └── *.crt, *.key          # PostgreSQL server certificates
├── minio/
│   └── *.crt, *.key          # MinIO server certificates
├── infra/
│   └── *.crt, *.key          # Infrastructure certificates
├── nginx/
│   └── *.crt, *.key          # Nginx HTTPS certificates
└── mongo/
    └── *.crt, *.key          # FerretDB/MongoDB certificates
```

> **Security Note**: The `files/pki/ca/` directory contains sensitive CA private key. Ensure proper backup and access control. The CA key should never be exposed or committed to version control.


## Certificate Validity

| Certificate Type  | Validity   | Controlled By              |
|-------------------|------------|----------------------------|
| CA Certificate    | 100 years  | Hardcoded (36500 days)     |
| Server/Client     | 20 years   | `cert_validity` (7300d)    |
| Nginx HTTPS       | ~1 year    | `nginx_cert_validity` (397d) |

> **Note**: Browser vendors (Safari, Chrome) limit trust for certificates over 398 days. Nginx uses a shorter validity by default for browser compatibility.


## Behavior

### ca_create = true (Default)

```
CA key exists?  CA cert exists?  Action
───────────────────────────────────────
No              No               Create new CA key and cert
Yes             No               Create cert using existing key
Yes             Yes              Reuse existing CA (no changes)
```

### ca_create = false

```
CA key exists?  CA cert exists?  Action
───────────────────────────────────────
Yes             Yes              Reuse existing CA
No              *                ABORT (fail the playbook)
*               No               ABORT (fail the playbook)
```


## Using External CA

To use your own enterprise or public CA:

1. Set `ca_create: false` in your configuration:

   ```yaml
   all:
     vars:
       ca_create: false
   ```

2. Place your CA files before running the playbook:

   ```bash
   mkdir -p files/pki/ca
   cp /path/to/your/ca.key files/pki/ca/ca.key
   cp /path/to/your/ca.crt files/pki/ca/ca.crt
   chmod 600 files/pki/ca/ca.key
   chmod 644 files/pki/ca/ca.crt
   ```

3. Run the playbook:

   ```bash
   ./infra.yml
   ```


## Issuing Additional Certificates

Use [`cert.yml`](../../cert.yml) to issue additional certificates with the CA:

```bash
# Issue a client certificate for database user
./cert.yml -e cn=dbuser_dba

# Issue certificate with custom SAN
./cert.yml -e cn=myservice -e '{"san":["DNS:myservice.local","IP:10.10.10.10"]}'

# Issue certificate to custom path
./cert.yml -e cn=custom -e key=files/pki/misc/custom.key -e crt=files/pki/misc/custom.crt
```

See `cert.yml` header comments for more examples.


## Trust the CA Certificate

To trust the self-signed CA on client machines:

### Linux (Debian/Ubuntu)

```bash
sudo cp files/pki/ca/ca.crt /usr/local/share/ca-certificates/pigsty-ca.crt
sudo update-ca-certificates
```

### Linux (RHEL/Rocky/Alma)

```bash
sudo cp files/pki/ca/ca.crt /etc/pki/ca-trust/source/anchors/pigsty-ca.crt
sudo update-ca-trust
```

### macOS

```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain files/pki/ca/ca.crt
```

### Windows

```powershell
Import-Certificate -FilePath files\pki\ca\ca.crt -CertStoreLocation Cert:\LocalMachine\Root
```


## Backup and Recovery

### Backup CA Files

```bash
# Backup CA key and certificate (IMPORTANT!)
cp -r files/pki/ca /path/to/secure/backup/

# Or archive with timestamp
tar -czvf pigsty-ca-$(date +%Y%m%d).tar.gz files/pki/ca/
```

### Restore CA Files

```bash
# Restore from backup
cp -r /path/to/secure/backup/ca files/pki/

# Ensure correct permissions
chmod 600 files/pki/ca/ca.key
chmod 644 files/pki/ca/ca.crt
```

> **Warning**: If you lose the CA private key, all certificates signed by it become unverifiable. You'll need to regenerate everything.


## See Also

- [`infra`](../infra): Infrastructure deployment
- [`pgsql`](../pgsql): PostgreSQL deployment (uses CA)
- [`etcd`](../etcd): ETCD deployment (uses CA)
- [`minio`](../minio): MinIO deployment (uses CA)
- [Certificate Guide](https://pigsty.io/docs/infra/cert): SSL/TLS configuration
