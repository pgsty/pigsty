# Role: openbao_remove

> Remove OpenBao KMS Cluster / Instance

| **Module**        | [OPENBAO](https://openbao.org/docs/) |
|-------------------|--------------------------------------|
| **Docs**          | https://pigsty.io/docs/conf/pgtde    |
| **Related Roles** | [`openbao`](../openbao)              |


## Overview

The `openbao_remove` role removes OpenBao instances from a cluster:

- Deregister from Victoria Metrics
- Gracefully leave the raft cluster (partial removal only)
- Stop the openbao service
- Remove the audit trail
- Remove data, TLS keys and the node copy of the seal key
- Uninstall packages (optional)

> **DANGER**: this is the most destructive removal in Pigsty. The OpenBao store holds the `pg_tde` **principal keys**. Destroying it makes every PostgreSQL cluster encrypted against this KMS permanently unreadable. Losing etcd costs you HA; losing the KMS costs you the data.


## Playbooks

| Playbook                                 | Description             |
|------------------------------------------|-------------------------|
| [`openbao-rm.yml`](../../openbao-rm.yml) | Remove OpenBao instance |


## File Structure

```
roles/openbao_remove/
├── defaults/
│   └── main.yml              # Default variables
├── meta/
│   └── main.yml              # Role metadata
└── tasks/
    ├── main.yml              # Entry point
    └── leave.yml             # Graceful raft peer removal
```


## Tags

### Tag Hierarchy

```
openbao_remove (full role)
│
├── openbao_safeguard          # Safeguard check (always) - ENABLED by default
│
├── openbao_pause              # Pause for confirmation (5s)
│
├── openbao_deregister         # Deregister from monitoring
│   └── rm_metrics             # Remove Victoria targets
│
├── openbao_leave              # Leave raft cluster gracefully
│
├── openbao_svc                # Stop openbao service
│
├── openbao_log                # Remove audit trail (if openbao_rm_log)
│
├── openbao_data               # Remove data + keys (if openbao_rm_data)
│
└── openbao_pkg                # Uninstall (if openbao_rm_pkg)
```


## Key Variables

| Variable             | Default | Description                |
|----------------------|---------|----------------------------|
| `openbao_safeguard`  | `false` | Prevent accidental removal |
| `openbao_rm_data`    | `true`  | Remove data directories    |
| `openbao_rm_log`     | `true`  | Remove log directories     |
| `openbao_rm_pkg`     | `false` | Uninstall openbao package  |


## Safeguard Protection

Enable safeguard to prevent accidental removal:

```yaml
openbao:
  vars:
    openbao_safeguard: true
```

Override with:

```bash
./openbao-rm.yml -l <target> -e openbao_safeguard=false
```


## Removal Scope

| Component    | What's Removed                              |
|--------------|---------------------------------------------|
| Monitoring   | `/infra/targets/openbao/<name>.yml`         |
| Config       | `/etc/openbao.d/`                           |
| TLS          | `/etc/openbao.d/tls/{ca,server}.{crt,key}`  |
| Seal key     | `/etc/openbao.d/seal/<cluster>-unseal.key`  |
| Data         | `{{ openbao_data }}`, `/var/lib/openbao`    |
| Audit trail  | `{{ openbao_log_dir }}`                     |
| Service      | `{{ systemd_dir }}/openbao.service`         |

### Never touched

The cluster-wide key material on the **admin node** survives the role, so a cluster can be rebuilt in place:

```
files/pki/bao/unseal.key                 # static seal key, decrypts the whole store
files/openbao/<cluster>-init.json        # root token + recovery shares
files/openbao/<cluster>-token.json       # pg_tde token issued by openbao_provision
files/pki/bao/<cluster>-*.crt / *.key    # per-member TLS material
```

Shred them by hand once you are certain the KMS will not be rebuilt.

> **Trap on rebuild**: `<cluster>-token.json` surviving is what lets a rebuilt cluster skip re-provisioning by mistake - `openbao_provision` only checks that this file exists on the controller, not that the `pg_tde` mount still exists in the (now empty) store. See [Rebuilding a Cluster](../openbao/README.md#rebuilding-a-cluster) in the `openbao` role.

> With the default layout `openbao_log_dir` is nested inside `openbao_data`, so `openbao_rm_data=true` takes the audit trail with it regardless of `openbao_rm_log`. To keep the audit trail, either archive it first or configure `openbao_log_dir` outside the data directory.


## Cluster Leave Process

Graceful raft removal is attempted **only when part of the cluster survives the play** - removing every member at once leaves nobody to evict peers from.

1. Pick a surviving member from `groups[openbao_cluster]` minus the play hosts
2. Read the root token from `files/openbao/<cluster>-init.json` on the controller
3. Run `bao operator raft remove-peer <instance>` against the surviving member
4. Stop the local service and purge

`bao operator raft remove-peer` needs a token with `sudo` capability on `sys/storage/raft/remove-peer`. The role opportunistically reuses the root token captured at init time; if that token was revoked - as the [`openbao`](../openbao) role's README recommends - the step is skipped and the play prints the manual command instead:

```bash
bao operator raft remove-peer <cluster>-<seq>
```

Always verify afterwards on a surviving member:

```bash
bao operator raft list-peers
```

A stale peer left in the raft configuration counts against quorum.


## Wipe and Rebuild

```bash
./openbao-rm.yml -l openbao -e openbao_safeguard=false   # destroy
./openbao.yml                                            # redeploy
```

The seal key on the admin node is reused, so the rebuilt cluster unseals normally - but it comes up **empty**. See [Rebuilding a Cluster](../openbao/README.md#rebuilding-a-cluster) in the `openbao` role for why this is not a recovery procedure.


## See Also

- [`openbao`](../openbao): Deploy the OpenBao KMS cluster
- [`ca`](../ca): Issues the OpenBao server certificates
- [OpenBao Documentation](https://openbao.org/docs/)
