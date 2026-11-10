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
- Save a final snapshot to admin node before removing the entire cluster, **abort if it fails**
- `raft remove-peer` on a surviving member (partial removal), **abort if it fails**
- Deregister from monitoring
- Stop openbao, remove haproxy entry, data, config and node key copies
- Optionally uninstall the package

Existing admin node `files/pki/vault/*` (unseal key, init material, snapshots) and
`/var/log/openbao` (audit trail) are **never** deleted.

Local snapshots in `vault_data` are removed along with the data, so the entire-cluster
removal first runs `vault-backup` on one member and fetches the result to
`files/pki/vault/backup/` on admin node. To remove a broken or never initialized
cluster that can not take a snapshot, add `--skip-tags vault_snapshot`.


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
├── vault_snapshot       # Final snapshot to admin node (entire cluster only)
├── vault_leave          # raft remove-peer on a surviving member (partial only)
├── vault_deregister     # Remove victoria targets
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
is restored from the final snapshot with `files/pki/vault/unseal.key`.

To bootstrap a brand-new empty cluster after removal, move `files/pki/vault/init.json`
away first, otherwise `vault.yml` refuses to initialize (it treats it as data loss).
