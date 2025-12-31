# Role: redis

> Deploy Redis Standalone, Cluster, or Sentinel

| **Module**        | [REDIS](https://pigsty.io/docs/redis)                |
|-------------------|------------------------------------------------------|
| **Docs**          | https://pigsty.io/docs/redis/                        |
| **Related Roles** | [`redis_remove`](../redis_remove), [`node`](../node) |


## Overview

The `redis` role deploys **Redis** instances in various modes:

- Install Redis packages
- Configure Redis node (directories, limits)
- Deploy Redis exporter for monitoring
- Create Redis instances (standalone/cluster/sentinel)
- Register to monitoring system

Redis supports three deployment modes:
- **Standalone**: Single instance or master-replica
- **Cluster**: Native Redis cluster with sharding
- **Sentinel**: High availability with automatic failover


## Playbooks

| Playbook                             | Description           |
|--------------------------------------|-----------------------|
| [`redis.yml`](../../redis.yml)       | Deploy Redis cluster  |
| [`redis-rm.yml`](../../redis-rm.yml) | Remove Redis cluster  |


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
│   ├── redis_check            # Check existing instance
│   ├── redis_clean            # Clean old data (if exists)
│   ├── redis_config           # Generate config files
│   ├── redis_launch           # Start Redis service
│   └── redis_reload           # Reload configuration
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

| Variable             | Default      | Description                       |
|----------------------|--------------|-----------------------------------|
| `redis_mode`         | `standalone` | Mode: standalone/cluster/sentinel |
| `redis_conf`         | `redis.conf` | Config template name              |
| `redis_bind_address` | `0.0.0.0`    | Listen address                    |

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
| `redis_safeguard`       | `false` | Prevent accidental removal |

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

Distributed cluster with automatic sharding:

```yaml
redis_mode: cluster
redis_cluster_replicas: 1
```

### Sentinel

HA mode with automatic failover:

```yaml
redis_mode: sentinel
redis_sentinel_monitor:
  - { name: mymaster, host: 10.10.10.10, port: 6379, quorum: 2 }
```


## See Also

- [`redis_remove`](../redis_remove): Remove Redis deployment
- [`node`](../node): Node provisioning
- [Redis Guide](https://pigsty.io/docs/redis/): Configuration documentation
