# Role: node_remove

> Remove Node Components and Deregister from Monitoring

| **Module**        | [NODE](https://pigsty.io/docs/node)                                           |
|-------------------|-------------------------------------------------------------------------------|
| **Docs**          | https://pigsty.io/docs/node/admin                                             |
| **Related Roles** | [`node`](../node), [`node_id`](../node_id), [`node_monitor`](../node_monitor) |


## Overview

The `node_remove` role removes node components and deregisters nodes from monitoring infrastructure:

- **Deregister**: Remove from Victoria Metrics, Nginx, Vector
- **Stop Services**: node_exporter, keepalived_exporter, HAProxy, Vector
- **Remove DNS**: VIP DNS records
- **Cleanup**: Configuration files, profile scripts


## Playbooks

| Playbook                           | Description              |
|------------------------------------|--------------------------|
| [`node-rm.yml`](../../node-rm.yml) | Remove node components   |


## File Structure

```
roles/node_remove/
├── defaults/
│   └── main.yml              # Default variables
├── meta/
│   └── main.yml              # Role dependencies
└── tasks/
    ├── main.yml              # Entry point
    └── nginx.yml             # Remove from Nginx
```


## Tags

### Tag Hierarchy

```
node_remove (full role)
│
├── node_deregister                # Deregister from monitoring
│   ├── rm_metrics                 # Remove from Victoria Metrics
│   ├── rm_dns                     # Remove VIP DNS records
│   └── rm_logs                    # Remove from Vector
│
├── haproxy_deregister             # Remove HAProxy from Nginx
│   └── rm_proxy                   # Remove Nginx upstream/location
│
├── vip                            # Stop keepalived service
│
├── haproxy                        # Stop HAProxy service
│
├── node_exporter                  # Stop node_exporter
│
├── vip_exporter                   # Stop keepalived_exporter
│
├── vector                         # Stop Vector service
│
└── profile                        # Remove shell profile scripts
```


## Key Variables

| Variable       | Default        | Description                     |
|----------------|----------------|---------------------------------|
| `nodename`     | (auto)         | Node name (from node_id)        |
| `node_cluster` | `nodes`        | Node cluster name (for VIP DNS) |
| `vip_enabled`  | `false`        | Whether VIP is enabled          |
| `vip_address`  | (none)         | VIP address to deregister       |
| `vector_data`  | `/data/vector` | Vector data directory           |


## Removal Scope

The role removes:

| Component        | What's Removed                                  |
|------------------|-------------------------------------------------|
| Node Target      | `/infra/targets/node/<ip>.yml`                  |
| Docker Target    | `/infra/targets/docker/<ip>.yml`                |
| Ping Target      | `/infra/targets/ping/<ip>.yml`                  |
| VIP Ping Target  | `/infra/targets/ping/<vip>---<ip>.yml`          |
| VIP DNS          | `/infra/hosts/<cluster>.vip`                    |
| HAProxy Nginx    | `/etc/nginx/conf.d/haproxy/upstream-<name>.conf`|
| HAProxy Nginx    | `/etc/nginx/conf.d/haproxy/location-<name>.conf`|
| Vector Config    | `/etc/vector/node.yaml`                         |
| Vector Data      | `/data/vector`                                  |
| Profile Scripts  | `/etc/profile.d/node.sh`, `node.alias.sh`       |


## See Also

- [`node`](../node): Node provisioning
- [`node_monitor`](../node_monitor): Node monitoring setup
- [`pg_remove`](../pg_remove): PostgreSQL removal
