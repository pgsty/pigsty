# Role: node_monitor

> Setup Node Monitoring Exporters and Register to Infra

| **Module**        | [NODE](https://pigsty.io/docs/node)                                                              |
|-------------------|--------------------------------------------------------------------------------------------------|
| **Docs**          | https://pigsty.io/docs/node/monitor                                                              |
| **Related Roles** | [`node`](../node), [`node_id`](../node_id), [`node_remove`](../node_remove), [`infra`](../infra) |


## Overview

The `node_monitor` role sets up monitoring components for Linux nodes:

- **node_exporter**: Collects system metrics (port 9100)
- **keepalived_exporter**: Collects VIP metrics (port 9650, when VIP enabled)
- **vector**: Log collection agent (define sinks, collect syslog)

It also registers the node to infrastructure monitoring:

- **Victoria Metrics**: Register as scrape targets
- **HAProxy**: Register to Nginx reverse proxy


## Playbooks

| Playbook                     | Description                                  |
|------------------------------|----------------------------------------------|
| [`node.yml`](../../node.yml) | Full node provisioning (includes monitoring) |


## File Structure

```
roles/node_monitor/
├── defaults/
│   └── main.yml                  # Default variables
├── files/
│   ├── node_exporter.svc         # node_exporter systemd service
│   └── keepalived_exporter.svc   # keepalived_exporter systemd service
├── meta/
│   └── main.yml                  # Role dependencies
├── tasks/
│   ├── main.yml                  # Entry point
│   └── vector.yml                # Vector configuration
└── templates/
    ├── vector.toml.j2            # Vector configuration
    └── node.yaml                 # Vector node log config
```


## Tags

### Tag Hierarchy

```
node_monitor (from node.yml)
│
├── haproxy_register               # Register HAProxy to Nginx
│
├── vip_dns                        # Register VIP DNS name
│
├── node_exporter                  # node_exporter setup
│   ├── node_exporter_config       # Generate config
│   └── node_exporter_launch       # Start service
│
├── vip_exporter                   # keepalived_exporter (when VIP enabled)
│   ├── vip_exporter_config        # Generate config
│   └── vip_exporter_launch        # Start service
│
├── node_register                  # Register to monitoring
│   └── add_metrics                # Register to Victoria Metrics
│
└── vector                         # Vector log agent
    ├── vector_config              # Generate config
    └── vector_launch              # Start service
```


## Key Variables

### node_exporter

| Variable                | Default | Description          |
|-------------------------|---------|----------------------|
| `node_exporter_enabled` | `true`  | Enable node_exporter |
| `node_exporter_port`    | `9100`  | Listen port          |
| `node_exporter_options` | `''`    | Extra CLI options    |

### keepalived_exporter

| Variable            | Default | Description             |
|---------------------|---------|-------------------------|
| `vip_enabled`       | `false` | Enable VIP and exporter |
| `vip_exporter_port` | `9650`  | Listen port             |

### Vector

| Variable         | Default        | Description             |
|------------------|----------------|-------------------------|
| `vector_enabled` | `true`         | Enable vector log agent |
| `vector_port`    | `9115`         | Metrics port            |
| `vector_data`    | `/data/vector` | Data directory          |

### HAProxy

| Variable                | Default | Description          |
|-------------------------|---------|----------------------|
| `haproxy_enabled`       | `true`  | Enable HAProxy       |
| `haproxy_exporter_port` | `9101`  | HAProxy metrics port |


## Exporter Ports

| Exporter            | Default Port | Description            |
|---------------------|--------------|------------------------|
| node_exporter       | 9100         | System metrics         |
| haproxy_exporter    | 9101         | HAProxy metrics        |
| vector              | 9115         | Vector metrics         |
| keepalived_exporter | 9650         | VIP/Keepalived metrics |


## Registered Targets

### Victoria Metrics

Creates target files at `/infra/targets/node/<ip>.yml`:

```yaml
- labels: { ip: 10.10.10.11, ins: pg-test-1, cls: pg-test }
  targets:
    - 10.10.10.11:9100    # node_exporter
    - 10.10.10.11:9101    # haproxy_exporter
    - 10.10.10.11:9115    # vector
```

### Ping Targets

Creates ping targets at `/infra/targets/ping/<ip>.yml` for ICMP monitoring.


## See Also

- [`node`](../node): Node provisioning
- [`node_remove`](../node_remove): Remove node components
- [`infra`](../infra): Infrastructure monitoring stack
