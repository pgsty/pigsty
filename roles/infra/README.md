# Role: infra

> Deploy Pigsty Infrastructure Components on Admin Nodes

| **Module**        | [INFRA](https://pigsty.io/docs/infra)                                        |
|-------------------|------------------------------------------------------------------------------|
| **Docs**          | https://pigsty.io/docs/infra/                                                |
| **Related Roles** | [`repo`](../repo), [`ca`](../ca), [`node`](../node), [`haproxy`](../haproxy) |


## Overview

The `infra` role deploys the Pigsty infrastructure stack on admin nodes:

- **DNS**: Dnsmasq for local DNS resolution
- **Nginx**: Web server and reverse proxy
- **Victoria Metrics**: Time-series database for metrics
- **Victoria Logs**: Log aggregation and storage
- **Victoria Traces**: Distributed tracing backend
- **VMAlert**: Alert rule evaluation engine
- **Alertmanager**: Alert management and routing
- **Blackbox Exporter**: Probe-based monitoring
- **Grafana**: Visualization and dashboards


## Playbooks

| Playbook                             | Description                    |
|--------------------------------------|--------------------------------|
| [`infra.yml`](../../infra.yml)       | Full infrastructure deployment |
| [`infra-rm.yml`](../../infra-rm.yml) | Remove infrastructure          |


## File Structure

```
roles/infra/
├── defaults/
│   └── main.yml              # Default variables
├── meta/
│   └── main.yml              # Role dependencies
├── tasks/
│   ├── main.yml              # Entry point
│   ├── user.yml              # [infra_user] Create infra users
│   ├── dir.yml               # [infra_dir] Create directories
│   ├── env.yml               # [infra_env] Environment setup
│   ├── pkg.yml               # [infra_pkg] Install packages
│   ├── cert.yml              # [infra_cert] Issue certificates
│   ├── dns.yml               # [dns] Dnsmasq setup
│   ├── nginx.yml             # [nginx] Nginx setup
│   ├── victoria.yml          # [victoria] Victoria Metrics/Logs
│   ├── alertmanager.yml      # [alertmanager] Alert management
│   ├── blackbox.yml          # [blackbox] Blackbox exporter
│   ├── grafana.yml           # [grafana] Grafana setup
│   └── register.yml          # [infra_register] Self-registration
├── templates/
│   ├── nginx.conf.j2         # Nginx main config
│   ├── dnsmasq.conf.j2       # Dnsmasq config
│   ├── vmalert.yml.j2        # VMAlert config
│   ├── alertmanager.yml.j2   # Alertmanager config
│   └── ...
└── vars/
    └── main.yml              # Internal variables
```


## Tags

### Tag Hierarchy

```
infra (full role)
│
├── infra_user                 # Create infra group/users
│
├── infra_dir                  # Create directories
│
├── infra_env                  # Environment setup
│   ├── env_dir                # Environment directories
│   ├── env_pg                 # PostgreSQL client environment
│   └── env_var                # Environment variables
│
├── infra_pkg                  # Install packages
│   └── infra_uv               # Install uv (Python)
│
├── infra_cert                 # Issue certificates
│   ├── infra_cert_issue       # Sign certificates
│   └── infra_cert_copy        # Copy certificates
│
├── dns                        # Dnsmasq DNS server
│   ├── dns_config             # Generate config
│   ├── dns_record             # DNS records
│   └── dns_launch             # Start service
│
├── nginx                      # Nginx web server
│   ├── nginx_config           # Generate config
│   ├── nginx_cert             # SSL certificates
│   ├── nginx_static           # Static files
│   ├── nginx_launch           # Start service
│   └── nginx_exporter         # Metrics exporter
│
├── victoria                   # Victoria Metrics stack
│   ├── vmetrics               # VictoriaMetrics
│   │   ├── vmetrics_clean     # Clean old data
│   │   ├── vmetrics_config    # Generate config
│   │   └── vmetrics_launch    # Start service
│   ├── vlogs                  # VictoriaLogs
│   │   ├── vlogs_clean        # Clean old data
│   │   ├── vlogs_config       # Generate config
│   │   └── vlogs_launch       # Start service
│   ├── vtraces                # VictoriaTraces
│   │   ├── vtraces_clean      # Clean old data
│   │   ├── vtraces_config     # Generate config
│   │   └── vtraces_launch     # Start service
│   └── vmalert                # VMAlert
│       ├── vmalert_config     # Generate config
│       └── vmalert_launch     # Start service
│
├── alertmanager               # Alertmanager
│   ├── alertmanager_config    # Generate config
│   └── alertmanager_launch    # Start service
│
├── blackbox                   # Blackbox exporter
│   ├── blackbox_config        # Generate config
│   └── blackbox_launch        # Start service
│
├── grafana                    # Grafana
│   ├── grafana_clean          # Clean old data
│   ├── grafana_config         # Generate config
│   ├── grafana_plugin         # Install plugins
│   ├── grafana_launch         # Start service
│   └── grafana_provision      # Provision dashboards
│
└── infra_register             # Self-registration
```


## Key Variables

### DNS

| Variable               | Default | Description                |
|------------------------|---------|----------------------------|
| `dns_enabled`          | `true`  | Enable Dnsmasq             |
| `dns_port`             | `53`    | DNS listen port            |

### Nginx

| Variable         | Default  | Description  |
|------------------|----------|--------------|
| `nginx_enabled`  | `true`   | Enable Nginx |
| `nginx_sslmode`  | `enable` | SSL mode     |
| `nginx_port`     | `80`     | HTTP port    |
| `nginx_ssl_port` | `443`    | HTTPS port   |

### Victoria Metrics

| Variable               | Default | Description                |
|------------------------|---------|----------------------------|
| `vmetrics_enabled`     | `true`  | Enable VictoriaMetrics     |
| `vmetrics_clean`       | `false` | Clean data during init     |
| `vmetrics_port`        | `8428`  | Listen port                |

### Victoria Logs

| Variable               | Default | Description                |
|------------------------|---------|----------------------------|
| `vlogs_enabled`        | `true`  | Enable VictoriaLogs        |
| `vlogs_clean`          | `false` | Clean data during init     |
| `vlogs_port`           | `9428`  | Listen port                |

### Victoria Traces

| Variable               | Default | Description                |
|------------------------|---------|----------------------------|
| `vtraces_enabled`      | `true`  | Enable VictoriaTraces      |
| `vtraces_clean`        | `false` | Clean data during init     |
| `vtraces_port`         | `10428` | Listen port                |

### VMAlert

| Variable               | Default | Description                |
|------------------------|---------|----------------------------|
| `vmalert_enabled`      | `true`  | Enable VMAlert             |
| `vmalert_port`         | `8880`  | Listen port                |

### Grafana

| Variable                 | Default  | Description    |
|--------------------------|----------|----------------|
| `grafana_enabled`        | `true`   | Enable Grafana |
| `grafana_port`           | `3000`   | Listen port    |
| `grafana_admin_username` | `admin`  | Admin username |
| `grafana_admin_password` | `pigsty` | Admin password |

### Blackbox Exporter

| Variable               | Default | Description                |
|------------------------|---------|----------------------------|
| `blackbox_enabled`     | `true`  | Enable Blackbox Exporter   |
| `blackbox_port`        | `9115`  | Listen port                |

### Alertmanager

| Variable               | Default | Description                |
|------------------------|---------|----------------------------|
| `alertmanager_enabled` | `true`  | Enable Alertmanager        |
| `alertmanager_port`    | `9059`  | Listen port                |

Full parameter list: [INFRA Configuration](https://pigsty.io/docs/infra/param)


## Service Ports

| Service          | Default Port | Description           |
|------------------|--------------|-----------------------|
| Dnsmasq          | 53           | DNS service           |
| Nginx            | 80/443       | HTTP/HTTPS            |
| VictoriaMetrics  | 8428         | Metrics database      |
| VictoriaLogs     | 9428         | Log aggregation       |
| VictoriaTraces   | 10428        | Distributed tracing   |
| VMAlert          | 8880         | Alert evaluation      |
| Alertmanager     | 9059         | Alert management      |
| Blackbox         | 9115         | Probe exporter        |
| Grafana          | 3000         | Visualization         |


## See Also

- [`repo`](../repo): Software repository
- [`ca`](../ca): Certificate authority
- [`node`](../node): Node provisioning
- [INFRA Architecture](https://pigsty.io/docs/infra/arch): Architecture documentation
