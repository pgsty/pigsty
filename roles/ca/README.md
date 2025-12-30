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
- Create PKI directory structure

The CA is used to sign certificates for:
- PostgreSQL server/client SSL
- Patroni REST API
- etcd cluster communication
- MinIO cluster communication
- Nginx HTTPS
- Infrastructure services


## Playbooks

| Playbook                       | Description                  |
|--------------------------------|------------------------------|
| [`infra.yml`](../../infra.yml) | Infrastructure (includes CA) |


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


## Key Variables

| Variable    | Default | Description                |
|-------------|---------|----------------------------|
| `ca_create` | `true`  | Create CA if not exists    |


## PKI Directory Structure

```
files/pki/
├── ca/
│   ├── ca.key                # CA private key (keep secure!)
│   └── ca.crt                # CA certificate
├── csr/
│   └── *.csr                 # Certificate signing requests
├── etcd/
│   └── *.crt, *.key          # ETCD certificates
├── pgsql/
│   └── *.crt, *.key          # PostgreSQL certificates
├── minio/
│   └── *.crt, *.key          # MinIO certificates
├── infra/
│   └── *.crt, *.key          # Infrastructure certificates
└── nginx/
    └── *.crt, *.key          # Nginx certificates
```


## Certificate Validity

| Certificate | Validity |
|-------------|----------|
| CA          | 100 years (36500 days) |
| Server      | 100 years (default)     |


## Behavior

### ca_create = true (Default)

- If CA key/cert don't exist: Create new CA
- If CA key/cert exist: Reuse existing CA

### ca_create = false

- If CA key/cert exist: Reuse existing CA
- If CA key/cert don't exist: **ABORT** (fail the playbook)

This allows using externally provided CA certificates.


## Using External CA

To use your own CA:

1. Set `ca_create: false`
2. Place your CA files:
   - `files/pki/ca/ca.key` (private key)
   - `files/pki/ca/ca.crt` (certificate)
3. Run the playbook


## See Also

- [`infra`](../infra): Infrastructure deployment
- [`pgsql`](../pgsql): PostgreSQL deployment (uses CA)
- [Certificate Guide](https://pigsty.io/docs/infra/cert): SSL/TLS configuration
