# Role: vault

> Deploy VAULT Secret & Key Management Cluster (OpenBao)

| **Module**        | [VAULT](https://pigsty.io/docs/vault)              |
|-------------------|----------------------------------------------------|
| **Docs**          | https://pigsty.io/docs/vault/                      |
| **Related Roles** | `vault_remove`, `pgsql` (pg_tde), `minio` (kes), `ca` |


## Overview

The `vault` role deploys an **OpenBao** cluster (MPL-2.0, Vault API compatible)
on the fixed group `vault`:

- Install `openbao` package
- Issue TLS certificates with Pigsty CA
- Generate a static auto-unseal key on admin node
- Configure raft storage and launch OpenBao
- Initialize the cluster once, on the member with the smallest `vault_seq`
- Enable `secret/` (kv v2), `transit/` and `approle/` for business use
- Expose an HA entry on the node L2 VIP via haproxy (if enabled)
- Install a daily snapshot job, register to monitoring

Consumer automation is planned separately: PGSQL `pg_mode: pgtde` clusters
will use `tde/<pg_cluster>`; KES for MINIO will use `kes/<minio_cluster>`.
This server role does not yet configure pg_tde or deploy KES.


## Playbooks

| Playbook       | Description                         |
|----------------|-------------------------------------|
| `vault.yml`    | Deploy / update VAULT cluster       |
| `vault-rm.yml` | Remove VAULT cluster or members     |


## File Structure

```text
roles/vault/
├── defaults/main.yml         # Default variables
├── meta/main.yml             # Role metadata
├── tasks/
│   ├── main.yml              # Entry point
│   ├── config.yml            # [vault_config] cert, seal key, config
│   ├── init.yml              # [vault_init] one-time cluster init
│   ├── launch.yml            # [vault_launch] serialized restart and readiness
│   └── provision.yml         # [vault_provision] default engines & tokens
└── templates/
    ├── openbao.hcl           # OpenBao server config
    ├── openbao.svc           # Systemd service unit
    ├── openbao.logrotate     # Audit log rotation
    ├── bao.sh                # CLI environment (/etc/profile.d)
    ├── vault-backup          # Snapshot script (/usr/local/bin)
    └── vault.cfg             # Haproxy entry on vip (if enabled)
```


## Tags

```text
vault (full role)
│
├── vault_assert               # Validate identity, derive topology (always)
├── vault_install              # Install openbao package
├── vault_dir                  # Create directories
├── vault_config               # Configure vault
│   ├── vault_cert             # TLS certificates
│   │   ├── vault_cert_issue   # Issue certificates on admin node
│   │   └── vault_cert_copy    # Copy certificates to node
│   ├── vault_seal             # Generate & copy static unseal key
│   └── vault_conf             # openbao.hcl, systemd, cli env, logrotate
├── vault_launch               # Start openbao (restart only on change)
├── vault_init                 # One-time init on the smallest seq member
├── vault_provision            # secret/ transit/ approle, backup token
├── vault_haproxy              # Haproxy entry on vip:8200 (if vip enabled)
├── vault_backup               # vault-backup script & daily crontab
└── vault_register             # Register to monitoring (add_metrics)
```


## Variables

| Variable        | Level    | Default        | Description                                   |
|-----------------|----------|----------------|-----------------------------------------------|
| `vault_seq`     | INSTANCE | **required**   | Instance number, instance name `vault-<seq>`  |
| `vault_cluster` | CLUSTER  | `vault`        | Cluster name for monitoring labels            |
| `vault_data`    | CLUSTER  | `/data/vault`  | Raft storage (`raft/`) and snapshots (`backup/`) |
| `vault_port`    | GLOBAL   | `8200`         | API port, raft cluster port is `vault_port+1` |
| `vault_domain`  | GLOBAL   | `vault.pigsty` | Service domain for cert SAN and all clients   |

Removal protection is controlled by `vault_safeguard` (**true** by default) in the `vault_remove` role.


## Topology

Topology is derived from the member count of group `vault`, there is no profile parameter:

| Members | Fault Tolerance | Mode       | Entry                                       |
|---------|-----------------|------------|---------------------------------------------|
| 1       | 0               | Lab        | `vault.pigsty` -> the member                |
| 2       | 0               | (warning)  | losing either member loses quorum           |
| 3       | 1               | Production | `vault.pigsty` -> node vip, haproxy -> active |

For production, enable node vip on the `vault` group (existing NODE parameters):

```yaml
vault:
  hosts:
    10.10.10.11: { vault_seq: 1 }
    10.10.10.12: { vault_seq: 2 }
    10.10.10.13: { vault_seq: 3 }
  vars: { node_cluster: vault, vip_enabled: true, vip_vrid: 129, vip_address: 10.10.10.8 }
# all.vars
node_etc_hosts: [ '10.10.10.8 vault.pigsty' ]
```

OpenBao listens on `<node_ip>:8200` and `127.0.0.1:8200` only, leaving `<vip>:8200` to haproxy.
Members that do not hold the vip need `net.ipv4.ip_nonlocal_bind=1` to bind it: all node tuned
profiles set it, `vault_haproxy` aborts otherwise (e.g. with `node_tune: none`).
Standby reads are disabled (`disable_standby_reads`): a standby forwards every request to the
active member, so any member gives read-after-write consistency.
Use the same `node_cluster` on these members so NODE derives the same VRRP authentication.
Configuration updates restart one member at a time and wait for it to rejoin before continuing.


## Key Material

Everything lives in `files/pki/vault/` on admin node, alongside the CA (`files/pki/*` is git-ignored):

| File                  | Content                                        |
|-----------------------|------------------------------------------------|
| `unseal.key`          | static seal key (32 bytes), members auto-unseal with it |
| `init.json`           | root token & recovery keys from `bao operator init` |
| `backup.token`        | snapshot-only token used by `vault-backup`     |
| `backup/*.snap`       | initial snapshot, and the final one before removal |
| `vault-<seq>.crt/key` | server certificates                            |

The snapshot and matching `unseal.key` recover the encrypted storage. Keep
`init.json` as well: the original root token or recovery shares are needed for
administrative access after restore. Recreate the service configuration, TLS
files, and the writable audit directory before restoring. Audit device settings
are persisted in the snapshot; an inaccessible audit path prevents normal startup.


## Init Rule

`bao operator init` runs only when all of the following hold, so expanding with `-l <ip>`
or rebuilding a member never bootstraps a second, empty cluster:

1. this member has the smallest `vault_seq`
2. every member is reachable and reports *not initialized*
3. `files/pki/vault/init.json` does not exist on admin node


## Backup

Every member runs `vault-backup` daily, pulling a snapshot from the **active** member
into `/data/vault/backup/` (keeps 7). Run `vault-backup` by hand for an ad-hoc snapshot.
These snapshots live on the members: copy them off the cluster yourself. Admin node only
gets the initial snapshot, and a final one when `vault-rm.yml` removes the entire cluster.

`vault_provision` validates `files/pki/vault/backup.token` on every run and reissues it when
it is missing, empty, or invalid (e.g. left by a previous cluster or after a snapshot restore),
keeping the replaced file as `backup.token.*~`. Run `-t vault_provision,vault_backup` to refresh it.

Each success writes `vault_backup_last_success_timestamp_seconds` and `vault_backup_size_bytes`
to `/var/lib/node_exporter/textfile/vault.prom`, `VaultBackupStale` fires when a member has no
successful snapshot for 26h (or never). Cron output goes to journald: `journalctl -t vault-backup`.


## Monitoring

Metrics are scraped from each member over HTTPS (`/v1/sys/metrics`, no token), see the `Vault Overview` dashboard.
Alerts: `VaultDown`, `VaultSealed`, `VaultNoLeader`, `VaultNoFailureTolerance`, `VaultAuditFailure`, `VaultBackupStale`.


## See Also

- `vault_remove`: Remove VAULT cluster or members
- [VAULT Guide](https://pigsty.io/docs/vault/): Configuration & administration
- [OpenBao Docs](https://openbao.org/docs/)
