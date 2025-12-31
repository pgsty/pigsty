# Role: minio_remove

> Remove MinIO Instance from Node

| **Module**        | [MINIO](https://pigsty.io/docs/minio)       |
|-------------------|---------------------------------------------|
| **Docs**          | https://pigsty.io/docs/minio/admin          |
| **Related Roles** | [`minio`](../minio)                         |


## Overview

The `minio_remove` role removes MinIO instances:

- Check safeguard protection
- Pause for confirmation (3 seconds)
- Deregister from Victoria Metrics
- Remove DNS records (dnsmasq and /etc/hosts)
- Stop MinIO service (graceful then force)
- Remove data directories (optional)
- Uninstall packages (optional)

**WARNING**: Removing MinIO will destroy all stored objects. Ensure backups exist.


## Playbooks

| Playbook                             | Description           |
|--------------------------------------|-----------------------|
| [`minio-rm.yml`](../../minio-rm.yml) | Remove MinIO instance |


## File Structure

```
roles/minio_remove/
├── defaults/
│   └── main.yml              # Default variables
├── meta/
│   └── main.yml              # Role dependencies
└── tasks/
    └── main.yml              # Removal logic
```


## Tags

### Tag Hierarchy

```
minio_remove (full role)
│
├── minio-id                   # Calculate identity/data paths
│
├── minio_safeguard            # Safeguard check (always)
│
├── minio_pause                # Pause for confirmation (3s)
│
├── minio_deregister           # Deregister from monitoring
│   ├── rm_metrics             # Remove Victoria targets
│   └── rm_dns                 # Remove DNS records (dnsmasq & /etc/hosts)
│
├── minio_svc                  # Stop MinIO service
│
├── minio_data                 # Remove data directories
│
└── minio_pkg                  # Uninstall packages
```


## Key Variables

| Variable          | Default | Description                    |
|-------------------|---------|--------------------------------|
| `minio_safeguard` | `false` | Prevent accidental removal     |
| `minio_rm_data`   | `true`  | Remove data and config files   |
| `minio_rm_pkg`    | `false` | Uninstall MinIO packages       |


## Safeguard Protection

Enable safeguard to prevent accidental removal:

```yaml
minio:
  vars:
    minio_safeguard: true
```

Override with:
```bash
./minio-rm.yml -l <target> -e minio_safeguard=false
```


## Removal Scope

| Component    | What's Removed                             |
|--------------|--------------------------------------------|
| Monitoring   | `/infra/targets/minio/<cluster>-<seq>.yml` |
| DNS          | `/infra/hosts/<cluster>-<seq>`, `/etc/hosts` entries |
| Service      | `minio.service` (systemd)                  |
| Config       | `/etc/default/minio`, `/home/minio/.minio` |
| Data         | All directories in `minio_data`            |
| Logging      | via syslog                                 |
| Packages     | `minio`, `mcli` (if enabled)               |


## Service Shutdown

The role uses a graceful shutdown sequence:

1. `systemctl stop minio`
2. Wait and retry if process still running
3. `kill` remaining processes
4. `kill -9` if still not terminated


## See Also

- [`minio`](../minio): Deploy MinIO cluster
- [MinIO Admin](https://pigsty.io/docs/minio/admin): Administration guide
