# Role: redis_remove

> Remove Redis Instances from Node

| **Module**        | [REDIS](https://pigsty.io/docs/redis)       |
|-------------------|---------------------------------------------|
| **Docs**          | https://pigsty.io/docs/redis/admin          |
| **Related Roles** | [`redis`](../redis)                         |


## Overview

The `redis_remove` role removes Redis instances from a node:

- Check safeguard protection
- Deregister from Victoria Metrics
- Deregister from Vector logging
- Stop redis_exporter service
- Stop Redis instance services
- Remove data directories (optional)
- Uninstall packages (optional)

Supports removing single instance (via `redis_port`) or entire node.


## Playbooks

| Playbook                             | Description           |
|--------------------------------------|-----------------------|
| [`redis-rm.yml`](../../redis-rm.yml) | Remove Redis instance |


## File Structure

```
roles/redis_remove/
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
redis_remove (full role)
│
├── redis_safeguard            # Safeguard check (always)
│
├── redis_deregister           # Deregister from monitoring
│   ├── rm_metrics             # Remove Victoria targets
│   └── rm_logs                # Remove Vector config
│
├── redis_exporter             # Stop redis_exporter
│
├── redis                      # Stop Redis services
│
├── redis_data                 # Remove data directories
│
└── redis_pkg                  # Uninstall packages
```


## Key Variables

| Variable          | Default | Description                    |
|-------------------|---------|--------------------------------|
| `redis_safeguard` | `false` | Prevent accidental removal     |
| `redis_clean`     | `true`  | Remove data directories        |
| `redis_uninstall` | `false` | Uninstall Redis packages       |


## CLI Arguments

### Remove Entire Node

```bash
./redis-rm.yml -l <host>
```

### Remove Single Instance

```bash
./redis-rm.yml -l <host> -e redis_port=6379
```


## Safeguard Protection

Enable safeguard to prevent accidental removal:

```yaml
redis-cluster:
  vars:
    redis_safeguard: true
```

Override with:
```bash
./redis-rm.yml -l <target> -e redis_safeguard=false
```


## Removal Scope

| Component    | What's Removed                              |
|--------------|---------------------------------------------|
| Monitoring   | `/infra/targets/redis/<cluster>-<node>.yml` |
| Logging      | `/etc/vector/redis.yaml`                    |
| Data         | `/data/redis/` (all instances)              |
| Packages     | `redis`, `redis_exporter` (if enabled)      |


## See Also

- [`redis`](../redis): Deploy Redis cluster
- [Redis Admin](https://pigsty.io/docs/redis/admin): Administration guide
