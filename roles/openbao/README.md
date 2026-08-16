# Role: openbao

> Deploy OpenBao KMS Cluster

| **Module**        | [OPENBAO](https://openbao.org/docs/)                                                               |
|-------------------|----------------------------------------------------------------------------------------------------|
| **Docs**          | https://pigsty.io/docs/conf/pgtde                                                                  |
| **Related Roles** | [`openbao_remove`](../openbao_remove), [`pgsql`](../pgsql), [`ca`](../ca), [`haproxy`](../haproxy) |


## Overview

The `openbao` role deploys an **OpenBao cluster** - an open-source, Apache-2.0 licensed fork of HashiCorp Vault - used by Pigsty as the **external Key Management Service (KMS)** backing PostgreSQL Transparent Data Encryption:

- Install openbao package
- Create configuration, data, log, TLS, and seal directories
- Issue and distribute TLS server certificates
- Generate and distribute a cluster-wide static unseal key
- Render the server config
- Launch the openbao systemd service and open firewall ports
- Initialize the cluster and persist the root token / recovery keys to the admin node
- Provision the `pg_tde` KV v2 mount, policy, and a long-lived token, persisted to the admin node

Its role in the installation is to hold the **principal keys** for the [`pg_tde`](https://docs.percona.com/pg-tde/) extension. With `pg_tde`, PostgreSQL encrypts heap data and WAL at rest, but the master key never lives on the database host - PostgreSQL fetches it from OpenBao over TLS at startup and on key rotation. This separates the encrypted data (on the PGSQL nodes) from the key material (in the KMS), which is the property most at-rest encryption compliance regimes actually require.

> `pg_tde` is available in the **Percona** PostgreSQL kernel. See the [`pgtde`](../../conf/pgtde.yml) configuration template.


## Playbooks

| Playbook                                 | Description            |
|------------------------------------------|------------------------|
| [`openbao.yml`](../../openbao.yml)       | Deploy OpenBao cluster |
| [`openbao-rm.yml`](../../openbao-rm.yml) | Remove OpenBao cluster |


## File Structure

```
roles/openbao/
├── defaults/
│   └── main.yml              # Default variables
├── meta/
│   └── main.yml              # Role metadata
├── tasks/
│   ├── main.yml              # Entry point
│   ├── config.yml            # [openbao_config]    Certs, seal key, configuration
│   ├── init.yml              # [openbao_init]       Cluster initialization
│   └── provision.yml         # [openbao_provision]  pg_tde KV mount, policy & token
└── templates/
    ├── openbao.hcl.j2        # OpenBao server configuration
    └── openbao.svc           # Systemd service unit
```


## Tags

### Tag Hierarchy

```
openbao (full role)
│
├── openbao_assert             # Validate identity parameters (openbao_seq)
│
├── openbao_install            # Install openbao package
│
├── openbao_dir                # Create data / log / conf / tls / seal directories
│
├── openbao_config             # Configure openbao
│   ├── openbao_cert           # TLS certificates
│   │   ├── openbao_cert_issue # Issue server certificate on localhost
│   │   └── openbao_cert_copy  # Copy ca.crt / server.crt / server.key to node
│   ├── openbao_seal           # Static unseal key
│   │   ├── openbao_seal_issue # Generate cluster-wide unseal key on localhost
│   │   └── openbao_seal_copy  # Copy unseal key to node (aborts if divergent)
│   └── openbao_conf           # Render openbao.hcl and systemd unit
│
├── openbao_launch             # Start openbao service, open firewall ports
│
├── openbao_init               # Initialize cluster, persist root token & recovery keys
│
├── openbao_provision          # Provision pg_tde KV mount, policy & token
│
└── openbao_register           # Register /v1/sys/metrics as a victoria-metrics target
```

> `openbao_init` is also applied to the initialization task itself when you run with `--tags openbao_provision`, so provisioning alone still ensures the cluster gets initialized first - you don't need to pass both tags.


## Key Variables

### Identity (Required)

| Variable          | Level    | Description              |
|-------------------|----------|--------------------------|
| `openbao_cluster` | CLUSTER  | OpenBao cluster name     |
| `openbao_seq`     | INSTANCE | Instance sequence number |

### Configuration

| Variable                  | Default              | Description                                            |
|---------------------------|----------------------|--------------------------------------------------------|
| `openbao_data`            | `/data/openbao`      | Raft data directory                                    |
| `openbao_log_dir`         | `/data/openbao/log`  | Log directory (holds the file audit device)            |
| `openbao_domain`          | `bao.pigsty`         | Domain name, added as a cert SAN                       |
| `openbao_api_port`        | `8200`               | API port - client requests, advertised for redirection |
| `openbao_cluster_port`    | `8201`               | Cluster port - inter-node request forwarding           |


## Configuration Example

OpenBao supports single-node and multi-node distributed modes:

### Single Node

```yaml
openbao:
  hosts:
    10.10.10.10: { openbao_seq: 1 }
  vars:
    openbao_cluster: openbao
```

### Multi-Node Distributed

```yaml
all:
  children:
    openbao:
      hosts:
        10.10.10.11: { openbao_seq: 1 }
        10.10.10.12: { openbao_seq: 2 }
        10.10.10.13: { openbao_seq: 3 }
      vars:
        openbao_cluster: openbao
  vars:
    openbao_data: /data/openbao
    openbao_domain: bao.pigsty
```

To expose the UI/API through the infra portal and load balancer:

```yaml
    infra_portal:
      openbao: { domain: bao.pigsty ,endpoint: "${admin_ip}:8200" ,scheme: https }

    haproxy_services:
      - name: openbao
        port: 8200
        options:
          - option httpchk
          - http-check send meth GET uri /v1/sys/health ver HTTP/1.1 hdr host bao.pigsty
          - http-check expect status 200
        servers:
          - { name: openbao-1 ,ip: 10.10.10.11 ,port: 8200 ,options: 'check-ssl ca-file /etc/pki/ca.crt check' }
          - { name: openbao-2 ,ip: 10.10.10.12 ,port: 8200 ,options: 'check-ssl ca-file /etc/pki/ca.crt check' }
          - { name: openbao-3 ,ip: 10.10.10.13 ,port: 8200 ,options: 'check-ssl ca-file /etc/pki/ca.crt check' }
```

See [`conf/pgtde.yml`](../../conf/pgtde.yml) for a complete production example.


## Cluster Topology

OpenBao uses **integrated Raft storage**, so the same quorum arithmetic as ETCD applies:

| Nodes | Fault Tolerance | Recommended |
|-------|-----------------|-------------|
| 1     | 0               | Demo / Dev  |
| 3     | 1               | Minimum HA  |
| 5     | 2               | Production  |

All members are listed as `retry_join` targets in `openbao.hcl`, so nodes discover the leader and join automatically on start. Adding a member is simply a matter of declaring it in the inventory and running `./openbao.yml -l <new_ip>`.

> The KMS is on the critical path for starting an encrypted PostgreSQL cluster: if no OpenBao node is reachable, `pg_tde` cannot fetch the principal key. Deploy at least 3 nodes in production and treat KMS availability as seriously as etcd availability.


## TLS Configuration

All OpenBao traffic is TLS-only (`tls_min_version = "tls13"`), using certificates signed by the [Pigsty CA](../ca):

- **CA**: `files/pki/ca/ca.crt` → `/etc/openbao.d/tls/ca.crt`
- **Server Cert**: `files/pki/bao/<instance>.crt` → `/etc/openbao.d/tls/server.crt`
- **Server Key**: `files/pki/bao/<instance>.key` → `/etc/openbao.d/tls/server.key`

The server certificate carries SANs for `localhost`, the cluster name, the instance name, `openbao_domain`, `127.0.0.1`, and the node IP - so clients may connect through any of those.

Clients (including PostgreSQL/`pg_tde`) must trust `/etc/pki/ca.crt`, which the NODE module already distributes to every managed host.


## Seal & Unseal

Pigsty configures OpenBao with the **static seal**, so the cluster auto-unseals on restart without manual key-share entry:

```hcl
seal "static" {
  current_key_id = "<cluster>-<sha256 prefix>"
  current_key    = "file:///etc/openbao.d/seal/<cluster>-unseal.key"
}
```

- The 32-byte key is generated **once** on the admin node at `files/pki/bao/unseal.key`, then copied to `/etc/openbao.d/seal/` on every member (mode `0640`, group `openbao`).
- The role **aborts the play** if a node already carries a seal key whose checksum differs from the admin node's - this prevents silently splitting a cluster across two key generations.
- `current_key_id` is derived from the key checksum, so the identifier changes if and only if the key material changes.

> **Critical**: `files/pki/bao/unseal.key` decrypts the entire OpenBao store, which in turn holds your TDE principal keys. Back it up alongside `files/pki/ca/ca.key` and guard it just as carefully. Losing it means losing access to every key OpenBao holds - and therefore to your encrypted data.


## Cluster Initialization

The `openbao_init` task runs once per cluster and is idempotent - it checks `bao status` first and skips an already-initialized cluster:

```bash
bao operator init -recovery-shares=5 -recovery-threshold=3 -format=json
```

The output is written at:

```
files/openbao/<openbao_cluster>-init.json    # mode 0600
```

This file contains the **initial root token** and the **recovery key shares**. Move it to your secret store as soon as the deployment completes:

1. Use the root token to create the policies and tokens your workloads need
2. Distribute the recovery shares to separate custodians (3 of 5 are required to recover)
3. Revoke the initial root token (`bao token revoke <token>`)
4. Delete the file from the admin node

An audit device writes every request to `{{ openbao_log_dir }}/audit.log` in JSON, and telemetry is exposed in Prometheus format.

Immediately after init, `openbao_provision` (tag `openbao_provision`, `tasks/provision.yml`) sets up what `pg_tde` needs on the KMS side, using the root token from the file above:

```bash
bao secrets enable -path=pg_tde -version=2 kv          # KV v2 mount for principal keys
bao policy write pg-tde-policy                         # least-privilege policy on that mount
bao token create -policy=pg-tde-policy -orphan -period=0 -format=json
```

The token is orphan (survives revocation of the root token) and periodic (renews indefinitely instead of expiring at a max TTL and taking an encrypted PostgreSQL cluster down with it). It is written to:

```
files/openbao/<openbao_cluster>-token.json    # mode 0600, raw `bao token create` output
```

This step is idempotent, but not the same way as `openbao_init`: it does **not** check server-side state, only whether `files/openbao/<cluster>-token.json` already exists on the controller. Delete that file to force a re-issue (the old token keeps working until you revoke it).


## Rebuilding a Cluster

```bash
# 1. destroy the existing cluster (safeguard is on by default)
./openbao-rm.yml -l openbao -e openbao_safeguard=false

# 2. redeploy on the same nodes
./openbao.yml
```

The cluster-wide key material on the admin node survives step 1 on purpose:

```
files/pki/bao/unseal.key            # reused, so the rebuilt cluster keeps the same seal key
files/openbao/<cluster>-init.json   # overwritten by the new init in step 2
files/openbao/<cluster>-token.json  # NOT overwritten - see warning below
```

Because the seal key is reused, `current_key_id` does not change and the rebuilt cluster unseals normally. The **contents** are gone, though: every secret, policy, token and `pg_tde` principal key must be recreated, and any PostgreSQL cluster encrypted against the old store stays unreadable.

> **Trap**: `openbao_provision` only checks whether `files/openbao/<cluster>-token.json` exists on the controller, not whether the `pg_tde` mount actually exists in the (now empty) rebuilt store. Since that file survives the rebuild, step 2 above will silently skip re-provisioning, leaving `pg_tde` pointed at a token for a mount that no longer exists. Delete `files/openbao/<cluster>-token.json` before redeploying, or re-provision explicitly afterwards with `./openbao.yml -l openbao -t openbao_provision`.

Rebuilding the KMS is not a recovery procedure - restore from a raft snapshot instead:

```bash
bao operator raft snapshot save bao.snap     # take one before you need it
bao operator raft snapshot restore bao.snap
```

To rebuild a **single member** rather than the whole cluster, remove and re-add it so the raft peer list stays consistent:

```bash
./openbao-rm.yml -l 10.10.10.13 -e openbao_safeguard=false
./openbao.yml    -l 10.10.10.13
```


## Monitoring

Metrics come straight from OpenBao's own telemetry - there is no separate exporter. The listener carries a `telemetry` sub-stanza so VictoriaMetrics can read `/v1/sys/metrics` without a token:

```hcl
listener "tcp" {
  telemetry {
    unauthenticated_metrics_access = true
  }
}
```

> A **sealed** node answers `503` on `/v1/sys/metrics`, so it is scraped as `up=0` and is indistinguishable from a dead node by metrics alone. `OpenbaoServerDown` therefore covers both cases, and `OpenbaoSealed` only fires for a node that still serves metrics while reporting itself sealed. Confirm with `bao status` on the node.


## Integration with pg_tde

Wiring a PostgreSQL cluster to this OpenBao cluster is **mostly automatic** - the manual `bao`/`psql` ceremony only matters for verification, rotation, and troubleshooting.

### 1. Deploy OpenBao, then a Percona kernel cluster with `pg_tde`

Deploy `openbao.yml` first so `files/openbao/<cluster>-token.json` exists before you bring up the database - the [`pgsql`](../pgsql) role reads it, and an empty/missing token means an encrypted cluster that cannot fetch its principal key at startup.

Use the [`pgtde`](../../conf/pgtde.yml) template as a starting point, or configure it yourself.

> The shipped [`conf/pgtde.yml`](../../conf/pgtde.yml) template does **not** currently declare an `openbao` group - add one (see [Configuration Example](#configuration-example) above) or point `openbao_cluster`/`openbao_domain` at an existing OpenBao deployment, otherwise `pg_tde` has no KMS to talk to.

### 2. OpenBao side - handled by `openbao_provision`

No manual `bao secrets enable` / `bao policy write` / `bao token create` needed: `openbao_provision` does this once per cluster (see [Cluster Initialization](#cluster-initialization) above) and leaves the token at `files/openbao/<openbao_cluster>-token.json` on the admin node.

### 3. PostgreSQL side - handled by `pgsql`

When `pg_mode` is `pgtde`, the [`pgsql`](../pgsql) role does the rest during cluster bootstrap:

- `tde.yml` (tag `pg_tde`) installs the OpenBao token to `/pg/tde-token` (mode `0600`) before Patroni starts, reading it from this role's `files/openbao/<cluster>-token.json`
- `pg-init-kms.sql`, run once against the primary, registers OpenBao as a global key provider and creates/sets the default principal key:
  ```sql
  SELECT pg_tde_add_global_key_provider_vault_v2(
      '{{ openbao_cluster }}',                                     -- provider name
      'https://{{ openbao_domain }}:{{ openbao_api_port }}',       -- KMS endpoint
      'pg_tde',                                                    -- mount path
      '/pg/tde-token',                                             -- token file installed above
      '/pg/cert/ca.crt'                                            -- CA to verify the KMS certificate
  );
  SELECT pg_tde_create_key_using_global_key_provider('{{ pg_cluster }}-principal-key', '{{ openbao_cluster }}');
  SELECT pg_tde_set_default_key_using_global_key_provider('{{ pg_cluster }}-principal-key', '{{ openbao_cluster }}');
  ```
- Patroni is configured with `pg_tde.wal_encrypt=on`, `pg_tde.enforce_encryption=on`, and `default_table_access_method=tde_heap`

### 4. Verify and rotate

```bash
export BAO_ADDR=https://bao.pigsty:8200
export BAO_CACERT=/etc/pki/ca.crt
bao login <root-token>       # from files/openbao/<cluster>-init.json
bao secrets list              # confirm the pg_tde/ mount
bao token lookup -accessor <accessor>   # inspect the pg_tde token without exposing it
```

```sql
SELECT * FROM pg_tde_global_key_provider_info();
SELECT pg_tde_key_info();          -- current database principal key
```

Rotate principal keys on your compliance schedule with `pg_tde_create_key_using_global_key_provider` + `pg_tde_set_default_key_using_global_key_provider`; rotate the OpenBao token itself by deleting `files/openbao/<cluster>-token.json` and re-running the playbook with `--tags openbao_provision`, then re-running the `pg_tde` tag on the PGSQL cluster to install the new token.

> Function names and signatures vary across `pg_tde` releases. Confirm against the [Percona pg_tde documentation](https://docs.percona.com/pg-tde/) for the version you deployed, and always test the whole flow - including a full restart of the PostgreSQL cluster with the KMS reachable - before putting real data behind it.

### 5. Operational consequences

- **Startup dependency**: an encrypted cluster cannot start without reaching OpenBao. Verify KMS health before any PGSQL restart, switchover, or PITR.
- **Backups**: pgBackRest backs up the *encrypted* files. A restore is useless without the corresponding principal key - the KMS and its unseal key are now part of your recovery plan, and should be exercised in every DR drill.
- **Token lifetime**: the periodic token in `files/openbao/<cluster>-token.json` renews indefinitely as long as it's used before it expires - don't let a PGSQL cluster stay disconnected from OpenBao longer than the token's TTL, or the provider will start failing at the worst possible moment.


## Administration

```bash
export BAO_ADDR=https://bao.pigsty:8200
export BAO_CACERT=/etc/pki/ca.crt

bao status                                # seal / init / HA status
bao operator raft list-peers              # raft cluster members
bao operator raft snapshot save bao.snap  # take a snapshot
bao secrets list                          # mounted secret engines
bao token lookup                          # inspect the current token

systemctl status openbao                  # service status
journalctl -u openbao -f                  # service logs
tail -f /data/openbao/log/audit.log       # audit log
```

Health endpoints (used by the HAProxy check):

```bash
curl --cacert /etc/pki/ca.crt https://bao.pigsty:8200/v1/sys/health
curl --cacert /etc/pki/ca.crt https://bao.pigsty:8200/v1/sys/metrics?format=prometheus
```


## Security Notes

The systemd unit is hardened: dedicated `openbao` user, `ProtectSystem=full`, `ProtectHome=read-only`, `PrivateTmp`, `PrivateDevices`, `NoNewPrivileges`, and `CAP_IPC_LOCK` so secrets are never swapped to disk.

Files to protect, in order of severity:

| Path                                       | Location    | Why it matters                                   |
|--------------------------------------------|-------------|--------------------------------------------------|
| `files/pki/bao/unseal.key`                 | Admin node  | Decrypts the whole OpenBao store                 |
| `files/openbao/<cluster>-init.json`        | Admin node  | Root token + recovery shares                     |
| `files/openbao/<cluster>-token.json`       | Admin node  | Orphan, non-expiring `pg_tde` token de/` mount   |
| `/etc/openbao.d/seal/<cluster>-unseal.key` | Members     | Same key, distributed for auto-unseal            |
| `files/pki/bao/*.key`                      | Admin node  | TLS server private keys                          |
| `{{ openbao_data }}`                       | Members     | Encrypted raft store (mode `0700`)               |
| `/pg/tde-token`                            | PGSQL nodes | Copy of the `pg_tde` token, installed by `pgsql` |

> The static seal trades key-ceremony security for operational simplicity: anyone with root on a member node can read the seal key and unseal the store offline. That is an acceptable trade when the threat model is *stolen disks and stolen backups* - which is exactly what `pg_tde` defends against. If your threat model includes a compromised database host, use an external seal (KMS/HSM/transit) instead and keep the seal key off the nodes entirely.


## See Also

- [`openbao_remove`](../openbao_remove): Remove OpenBao clusters and members
- [`ca`](../ca): Self-signed CA that issues OpenBao server certificates
- [`pgsql`](../pgsql): PostgreSQL deployment (`pg_tde` consumer)
- [`haproxy`](../haproxy): Load balancing the KMS endpoint
- [`conf/pgtde.yml`](../../conf/pgtde.yml): Percona + `pg_tde` configuration template
- [OpenBao Documentation](https://openbao.org/docs/)
- [Percona pg_tde Documentation](https://docs.percona.com/pg-tde/)
