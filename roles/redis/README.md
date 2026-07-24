# Role: redis

> Deploy Redis Instances and Monitoring

| **Module**        | [REDIS](https://pigsty.io/docs/redis) |
|-------------------|---------------------------------------|
| **Docs**          | https://pigsty.io/docs/redis/         |
| **Related Roles** | `redis_remove`, `node`                |


## Overview

The `redis` role deploys and manages **Redis** instances:

- Install Redis packages
- Configure Redis node (directories, limits)
- Deploy Redis exporter for monitoring
- Create standalone, cluster-enabled, or Sentinel instances
- Register to monitoring system

**Idempotent**: Re-running the playbook will update config and restart services.
Only nodes with `redis_cluster` defined will be affected.

The role supports three instance modes:

- **Standalone**: Single instance or master-replica
- **Cluster**: Enable Redis Cluster mode on each instance
- **Sentinel**: Launch Redis Sentinel instances

The role does not create or join a native cluster, and it does not generate
Sentinel monitor declarations. The current implementation does not consume
`redis_cluster_replicas` or `redis_sentinel_monitor`.


## Playbooks

| Playbook       | Description            |
|----------------|------------------------|
| `redis.yml`    | Deploy Redis instances |
| `redis-rm.yml` | Remove Redis cluster   |


## File Structure

```
roles/redis/
├── defaults/
│   └── main.yml              # Default variables
├── meta/
│   └── main.yml              # Role dependencies
├── tasks/
│   ├── main.yml              # Entry point
│   ├── node.yml              # [redis_node] Node setup
│   ├── exporter.yml          # [redis_exporter] Monitoring
│   └── instance.yml          # [redis_instance] Instance deployment
└── templates/
    ├── redis.conf            # Redis config template
    ├── redis-sentinel.conf   # Sentinel config template
    ├── redis.svc             # Systemd service template (unified for all modes)
    └── redis.yaml            # Vector logging config
```


## Tags

### Tag Hierarchy

```
redis (full role)
│
├── redis-id                   # Validate identity parameters
│
├── redis_node                 # Configure Redis node
│
├── redis_exporter             # Deploy redis_exporter
│
├── redis_instance             # Deploy Redis instances
│   ├── redis_config           # Generate config files
│   └── redis_launch           # Start Redis service
│
└── redis_register             # Register to monitoring
    ├── add_metrics            # Register Victoria targets
    └── add_logs               # Register Vector logging
```


## Key Variables

### Identity (Required)

| Variable          | Level    | Description               |
|-------------------|----------|---------------------------|
| `redis_cluster`   | CLUSTER  | Redis cluster name        |
| `redis_node`      | INSTANCE | Node sequence number      |
| `redis_instances` | INSTANCE | Dict of port → config     |

### Mode Configuration

| Variable             | Default      | Description                                |
|----------------------|--------------|--------------------------------------------|
| `redis_mode`         | `standalone` | Instance mode: standalone/cluster/sentinel |
| `redis_conf`         | `redis.conf` | Config template name                       |
| `redis_bind_address` | `0.0.0.0`    | Listen address                             |

### Filesystem

| Variable        | Default       | Description                                                                                        |
|-----------------|---------------|----------------------------------------------------------------------------------------------------|
| `redis_fs_main` | `/data/redis` | Redis data root directory; instance dirs are created under it (`/data` is rejected at deploy-time) |

### Resource Limits

| Variable           | Default       | Description              |
|--------------------|---------------|--------------------------|
| `redis_max_memory` | `1GB`         | Max memory per instance  |
| `redis_mem_policy` | `allkeys-lru` | Eviction policy          |

### Persistence

| Variable            | Default      | Description            |
|---------------------|--------------|------------------------|
| `redis_rdb_save`    | `['1200 1']` | RDB save directives    |
| `redis_aof_enabled` | `false`      | Enable AOF persistence |

### Security

| Variable                | Default | Description                |
|-------------------------|---------|----------------------------|
| `redis_password`        | `''`    | Auth password (empty=off)  |
| `redis_rename_commands` | `{}`    | Rename dangerous commands  |

### Monitoring

| Variable                  | Default | Description              |
|---------------------------|---------|--------------------------|
| `redis_exporter_enabled`  | `true`  | Install redis_exporter   |
| `redis_exporter_port`     | `9121`  | Exporter listen port     |


## Instance Definition

Define instances as a dict of port → config:

```yaml
redis-test:
  hosts:
    10.10.10.10:
      redis_node: 1
      redis_instances:
        6379: {}
        6380: { replica_of: '10.10.10.10 6379' }
```


## Deployment Modes

### Standalone (Default)

Single instance or master-replica pairs:

```yaml
redis_mode: standalone
redis_instances:
  6379: {}                                   # Leader
  6380: { replica_of: '10.10.10.10 6379' }   # Replica
```

### Native Cluster

Enable cluster mode and define instances as usual:

```yaml
redis_mode: cluster
redis_instances:
  6379: {}
```

After deployment, create or join the topology explicitly with `redis-cli --cluster`.
The role does not run cluster bootstrap or resharding commands.

### Sentinel

Launch a Sentinel instance:

```yaml
redis_mode: sentinel
redis_instances:
  26379: {}
```

The bundled template does not render monitored masters. Configure Sentinel
monitor targets separately before relying on automatic failover.


## See Also

- `redis_remove`: Remove Redis deployment
- `node`: Node provisioning
- [Redis Guide](https://pigsty.io/docs/redis/): Configuration documentation
