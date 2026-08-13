# Role: etcd_remove

> Remove ETCD Cluster Instance

| **Module**        | [ETCD](https://pigsty.io/docs/etcd) |
|-------------------|-------------------------------------|
| **Docs**          | https://pigsty.io/docs/etcd/admin   |
| **Related Roles** | `etcd`                              |


## Overview

The `etcd_remove` role removes ETCD instances from a cluster:

- Deregister from Victoria Metrics
- Gracefully leave the cluster
- Stop etcd service
- Remove data directories
- Uninstall packages (optional)

**WARNING**: Removing etcd nodes can affect cluster quorum. Ensure you maintain majority before removal.


## Playbooks

| Playbook      | Description          |
|---------------|----------------------|
| `etcd-rm.yml` | Remove ETCD instance |


## File Structure

```text
roles/etcd_remove/
├── defaults/
│   └── main.yml              # Default variables
├── meta/
│   └── main.yml              # Role dependencies
└── tasks/
    ├── main.yml              # Entry point
    └── leave.yml             # Graceful cluster leave
```


## Tags

### Tag Hierarchy

```text
etcd_remove (full role)
│
├── etcd_safeguard             # Safeguard check (always)
│
├── etcd_pause                 # Pause for confirmation (3s)
│
├── etcd_deregister            # Deregister from monitoring
│   └── rm_metrics             # Remove Victoria targets
│
├── etcd_leave                 # Leave cluster gracefully
│
├── etcd_svc                   # Stop etcd service
│   └── etcd_stop              # Alias for the service-stop task
│
├── etcd_data                  # Stop service and remove data (if etcd_rm_data)
│
└── etcd_pkg                   # Uninstall (if etcd_rm_pkg)
```


## Key Variables

| Variable         | Default      | Description                                |
|------------------|--------------|--------------------------------------------|
| `etcd_cluster`   | `etcd`       | Cluster/group identity                     |
| `etcd_seq`       | required     | Member sequence used in the instance name  |
| `etcd_data`      | `/data/etcd` | Primary data directory                     |
| `etcd_safeguard` | `false`      | Prevent accidental removal                 |
| `etcd_rm_data`   | `true`       | Remove data, config, unit, and helper files |
| `etcd_rm_pkg`    | `false`      | Uninstall the `etcd` package                |


## Safeguard Protection

Enable safeguard to prevent accidental removal:

```yaml
etcd:
  vars:
    etcd_safeguard: true
```

Override with:
```bash
./etcd-rm.yml -l <target> -e etcd_safeguard=false
```


## Removal Scope

| Component    | What's Removed                       |
|--------------|--------------------------------------|
| Monitoring   | `/infra/targets/etcd/<name>.yml`     |
| Config       | `/etc/etcd/`                         |
| Data         | `/data/etcd/`, `/var/lib/etcd/`      |
| Service      | `/etc/systemd/system/etcd.service`   |
| Environment  | `/etc/profile.d/etcdctl.sh`          |
| Vector       | `/etc/vector/etcd.yaml`              |


## Cluster Leave Process

1. Get current member ID
2. Call `etcdctl member remove <id>`
3. Stop local etcd service
4. Clean up data (optional)

If graceful leave fails, the play continues to stop the local service and,
with the default `etcd_rm_data: true`, remove its local state. The role does
not prove that the remaining members retain quorum; verify membership and
quorum before every real run and always limit the play to the exact member.


## See Also

- `etcd`: Deploy ETCD cluster
- [ETCD Admin](https://pigsty.io/docs/etcd/admin): Administration guide
