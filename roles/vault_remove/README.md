# Role: vault_remove

> Remove VAULT (OpenBao) Cluster or Members

| **Module**        | [VAULT](https://pigsty.io/docs/vault) |
|-------------------|---------------------------------------|
| **Docs**          | https://pigsty.io/docs/vault/admin    |
| **Related Roles** | `vault`                               |


## Overview

The `vault_remove` role removes vault members or the entire cluster:

- Honor `vault_safeguard` (**true by default**, unlike other `*_remove` roles)
- List `tde/*` / `kes/*` consumers before removing the entire cluster
- Deregister from monitoring
- `raft remove-peer` on a surviving member (partial removal), **abort if it fails**
- Stop openbao, remove haproxy entry, data, config and node key copies
- Optionally uninstall the package

Admin node `files/pki/vault/*` (unseal key, init material, snapshots) and
`/var/log/openbao` (audit trail) are **never** touched.


## Playbooks

| Playbook       | Description                     |
|----------------|---------------------------------|
| `vault-rm.yml` | Remove VAULT cluster or members |

```bash
./vault-rm.yml -l vault -e vault_safeguard=false          # remove entire cluster
./vault-rm.yml -l 10.10.10.13 -e vault_safeguard=false    # remove one member
bin/vault-rm                                               # entire cluster, asks to type the name
bin/vault-rm 10.10.10.13                                   # one member
```


## Tags

```text
vault_remove (full role)
│
├── vault_safeguard      # Abort unless vault_safeguard=false
├── vault_consumer       # List tde/* kes/* consumers (entire cluster only)
├── vault_pause          # Pause 5s for confirmation
├── vault_deregister     # Remove victoria targets
├── vault_leave          # raft remove-peer on a surviving member (partial only)
├── vault_svc            # Stop openbao, remove haproxy entry
├── vault_data           # Remove data, config, tls, key copies, snapshots
└── vault_pkg            # Uninstall openbao (vault_rm_pkg=true)
```


## Variables

| Variable          | Default | Description                         |
|-------------------|---------|-------------------------------------|
| `vault_safeguard` | `true`  | Prevent removal, override with `-e` |
| `vault_rm_data`   | `true`  | Remove data & config                |
| `vault_rm_pkg`    | `false` | Uninstall openbao package           |


## Danger

Destroying the vault cluster destroys the keys of pg_tde clusters and kes objects:
the encrypted data **and all its backups** become permanently unreadable, unless vault
is restored from a snapshot with `files/pki/vault/unseal.key`.

To bootstrap a brand-new empty cluster after removal, move `files/pki/vault/init.json`
away first, otherwise `vault.yml` refuses to initialize (it treats it as data loss).
