# Role: haproxy

> Deploy HAProxy Load Balancer for Service Exposure

| **Module**        | [NODE](https://pigsty.io/docs/node)            |
|-------------------|------------------------------------------------|
| **Docs**          | https://pigsty.io/docs/node/haproxy            |
| **Related Roles** | [`node`](../node), [`pgsql`](../pgsql)         |


## Overview

The `haproxy` role deploys **HAProxy** for load balancing and service exposure:

- Install HAProxy package
- Create configuration directory
- Render default and service configs
- Configure SELinux policies (if applicable)
- Launch HAProxy service
- Support config reload without restart

HAProxy is used by PostgreSQL clusters for connection pooling and load balancing across replicas.


## Playbooks

| Playbook                     | Description                          |
|------------------------------|--------------------------------------|
| [`node.yml`](../../node.yml) | Node provisioning (includes HAProxy) |


## File Structure

```
roles/haproxy/
├── defaults/
│   └── main.yml              # Default variables
├── files/
│   └── haproxy.svc           # Systemd service file
├── meta/
│   └── main.yml              # Role dependencies
├── tasks/
│   └── main.yml              # Main task list
└── templates/
    ├── haproxy.cfg.j2        # Default HAProxy config
    └── service.j2            # Service definition template
```


## Tags

### Tag Hierarchy

```
haproxy (full role)
│
├── haproxy_install            # Install HAProxy
│
├── haproxy_config             # Configure HAProxy
│   └── haproxy_firewall       # SELinux configuration
│
├── haproxy_launch             # Start HAProxy service
│
└── haproxy_reload             # Reload configuration
```


## Key Variables

### Basic Configuration

| Variable           | Default  | Description                    |
|--------------------|----------|--------------------------------|
| `haproxy_enabled`  | `true`   | Enable HAProxy on this node    |
| `haproxy_clean`    | `false`  | Wipe existing config on deploy |
| `haproxy_reload`   | `true`   | Reload after config changes    |

### Admin Interface

| Variable                 | Default  | Description                    |
|--------------------------|----------|--------------------------------|
| `haproxy_auth_enabled`   | `true`   | Enable admin authentication    |
| `haproxy_admin_username` | `admin`  | Admin page username            |
| `haproxy_admin_password` | `pigsty` | Admin page password            |
| `haproxy_exporter_port`  | `9101`   | Admin/metrics port             |

> ⚠️ **Security Warning**: The default password `pigsty` is publicly known.
> **Change `haproxy_admin_password` in production environments!**

### Timeouts

| Variable                | Default | Description                    |
|-------------------------|---------|--------------------------------|
| `haproxy_client_timeout`| `24h`   | Client connection timeout      |
| `haproxy_server_timeout`| `24h`   | Server connection timeout      |

### Services

| Variable           | Default | Description                    |
|--------------------|---------|--------------------------------|
| `haproxy_services` | `[]`    | List of services to expose     |


## Configuration Directory

```
/etc/haproxy/
├── haproxy.cfg           # Global defaults
├── pg-test-primary.cfg   # Service: port 5433
├── pg-test-replica.cfg   # Service: port 5434
├── pg-test-default.cfg   # Service: port 5435
├── pg-test-offline.cfg   # Service: port 5436
└── ...
```


## Service Definition

Define custom HAProxy services:

```yaml
haproxy_services:
  # PostgreSQL read-only replicas
  - name: pg-test-ro
    port: 5440
    ip: "*"
    protocol: tcp
    balance: leastconn
    maxconn: 20000
    default: 'inter 3s fastinter 1s downinter 5s rise 3 fall 3 on-marked-down shutdown-sessions slowstart 30s maxconn 3000 maxqueue 128 weight 100'
    options:
      - option httpchk
      - option http-keep-alive
      - http-check send meth OPTIONS uri /read-only
      - http-check expect status 200
    servers:
      - { name: pg-test-1, ip: 10.10.10.11, port: 5432, options: 'check port 8008', backup: true }
      - { name: pg-test-2, ip: 10.10.10.12, port: 5432, options: 'check port 8008' }
      - { name: pg-test-3, ip: 10.10.10.13, port: 5432, options: 'check port 8008' }

  # Redis cluster
  - name: redis-test
    port: 5441
    servers:
      - { name: redis-test-1-6379, ip: 10.10.10.11, port: 6379, options: check }
      - { name: redis-test-1-6380, ip: 10.10.10.11, port: 6380, options: check }
```

### Service Parameters

| Parameter   | Required | Default       | Description                    |
|-------------|----------|---------------|--------------------------------|
| `name`      | Yes      | -             | Unique service name            |
| `port`      | Yes      | -             | Listen port                    |
| `ip`        | No       | `*`           | Listen address                 |
| `protocol`  | No       | `tcp`         | Protocol (tcp/http)            |
| `balance`   | No       | `roundrobin`  | Load balance algorithm         |
| `maxconn`   | No       | `10000`       | Max frontend connections       |
| `options`   | No       | `[]`          | Additional HAProxy options     |
| `servers`   | Yes      | -             | Backend server list            |

### Load Balancing Algorithms

| Algorithm     | Description                                                    |
|---------------|----------------------------------------------------------------|
| `roundrobin`  | Round-robin selection (default, good for homogeneous servers) |
| `leastconn`   | Prefer server with fewest connections (good for OLTP)         |
| `source`      | Hash client IP for session affinity                           |
| `first`       | Use first available server (for active-standby)               |

### Health Check

For PostgreSQL clusters, HAProxy uses HTTP health checks against Patroni REST API:

```yaml
options:
  - option httpchk
  - option http-keep-alive
  - http-check send meth OPTIONS uri /read-only  # or /primary, /replica, /health
  - http-check expect status 200
servers:
  - { name: pg-test-1, ip: 10.10.10.11, port: 5432, options: 'check port 8008' }
```

**Patroni Health Check Endpoints** (port 8008):

| Endpoint      | Returns 200 When                          | Use Case          |
|---------------|-------------------------------------------|-------------------|
| `/primary`    | Instance is primary                       | Read-write service|
| `/replica`    | Instance is replica                       | Read-only service |
| `/read-only`  | Instance accepts read queries (any role)  | Read-only + backup|
| `/health`     | Instance is healthy (any role)            | General health    |


## Reload Configuration

Update services without restarting:

```bash
./node.yml -t haproxy_config,haproxy_reload
bin/pgsql-svc <cls>
```

This validates config before reload and only applies changes if valid.


## SELinux Handling

On RHEL/Rocky systems with SELinux enabled, the role automatically:

1. Sets `haproxy_connect_any` boolean to allow HAProxy to connect to any port
2. Installs a custom SELinux policy module (`haproxy_proc`) to allow HAProxy
   to read `/proc` filesystem for health monitoring

This is handled silently - if SELinux tools are not available, these steps are skipped.


## Platform Support

This role supports **RHEL/Rocky 8-10**, **Ubuntu 22-24**, and **Debian 12-13**.

The systemd service file is installed to `{{ systemd_dir }}/haproxy.service`,
where `systemd_dir` is determined by the `node_id` role based on OS detection.


## See Also

- [`node`](../node): Node provisioning
- [`pgsql`](../pgsql): PostgreSQL cluster
- [HAProxy Guide](https://pigsty.io/docs/node/haproxy): Configuration documentation
