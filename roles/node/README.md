# Role: node

> Provision and Configure Linux Nodes for Pigsty

| **Module**        | [NODE](https://pigsty.io/docs/node)                                                                                  |
|-------------------|----------------------------------------------------------------------------------------------------------------------|
| **Docs**          | https://pigsty.io/docs/node/                                                                                         |
| **Related Roles** | [`node_id`](../node_id), [`node_monitor`](../node_monitor), [`node_remove`](../node_remove), [`haproxy`](../haproxy) |


## Overview

The `node` role provisions Linux nodes with proper configuration for running Pigsty workloads:

- **Name & DNS**: Hostname, `/etc/hosts`, DNS resolution
- **Security**: Firewall, SELinux, sudo configuration
- **Certificates**: Install CA certificates
- **Packages**: Configure repos, install packages
- **Tuning**: Kernel parameters, sysctl, hugepages
- **Admin**: Create admin users, setup SSH keys
- **Time**: Timezone, NTP synchronization, crontab
- **VIP**: Optional L2 VIP with keepalived


## Playbooks

| Playbook                           | Description                  |
|------------------------------------|------------------------------|
| [`node.yml`](../../node.yml)       | Full node provisioning       |
| [`node-rm.yml`](../../node-rm.yml) | Remove node components       |


## File Structure

```
roles/node/
├── defaults/
│   └── main.yml              # Default variables
├── files/
│   └── ...                   # Static files
├── meta/
│   └── main.yml              # Role dependencies
├── tasks/
│   ├── main.yml              # Entry point
│   ├── dns.yml               # [node_hosts, node_resolv] DNS config
│   ├── sec.yml               # [node_sec] Security settings
│   ├── cert.yml              # [node_ca] CA certificates
│   ├── pkg.yml               # [node_repo, node_pkg] Package management
│   ├── tune.yml              # [node_tune] Kernel tuning
│   ├── admin.yml             # [node_admin] Admin user setup
│   ├── time.yml              # [node_time] Time synchronization
│   └── vip.yml               # [node_vip] Keepalived VIP
└── templates/
    ├── hosts.j2              # /etc/hosts template
    ├── resolv.conf.j2        # /etc/resolv.conf template
    ├── keepalived.conf.j2    # Keepalived configuration
    └── ...
```


## Tags

### Tag Hierarchy

```
node (full role)
│
├── node_name                  # Set hostname
│
├── node_hosts                 # Configure /etc/hosts
├── node_resolv                # Configure /etc/resolv.conf
│
├── node_sec                   # Security configuration
│   ├── node_firewall          # Firewall setup
│   └── node_selinux           # SELinux configuration
│
├── node_ca                    # Install CA certificates
│
├── node_repo                  # Configure package repos
├── node_pkg                   # Install packages
│
├── node_tune                  # System tuning
│   ├── node_feature           # CPU/kernel features
│   ├── node_kernel            # Kernel modules
│   ├── node_sysctl            # Sysctl parameters
│   └── node_hugepage          # Hugepages setup
│
├── node_admin                 # Admin configuration
│   ├── node_profile           # Shell profile
│   ├── node_ulimit            # Resource limits
│   ├── node_data              # Data directories
│   └── node_admin_user        # Admin user creation
│
├── node_time                  # Time configuration
│   ├── node_timezone          # Timezone setup
│   ├── node_ntp               # NTP synchronization
│   └── node_cron              # Crontab entries
│
└── node_vip                   # VIP configuration (optional)
    ├── vip_config             # Keepalived config
    ├── vip_launch             # Start keepalived
    └── vip_reload             # Reload keepalived
```


## Key Variables

### Identity

| Variable             | Default | Description        |
|----------------------|---------|--------------------|
| `nodename`           | (auto)  | Node name          |
| `node_cluster`       | `nodes` | Node cluster name  |
| `nodename_overwrite` | `true`  | Overwrite hostname |

### DNS

| Variable                 | Default | Description               |
|--------------------------|---------|---------------------------|
| `node_write_etc_hosts`   | `true`  | Write /etc/hosts          |
| `node_default_etc_hosts` | `[]`    | Static /etc/hosts entries |
| `node_dns_servers`       | `[]`    | DNS servers               |

### Security

| Variable             | Default | Description                                     |
|----------------------|---------|-------------------------------------------------|
| `node_selinux_mode`  | `enum`  | set selinux mode: enforcing,permissive,disabled |
| `node_firewall_mode` | `enum`  | firewall mode: off, none, zone, zone by default |


### Packages

| Variable            | Default | Description            |
|---------------------|---------|------------------------|
| `node_repo_modules` | `node`  | Repo modules to enable |
| `node_packages`     | `[]`    | Packages to install    |

### Admin

| Variable                  | Default | Description       |
|---------------------------|---------|-------------------|
| `node_admin_enabled`      | `true`  | Create admin user |
| `node_admin_username`     | `dba`   | Admin username    |
| `node_admin_ssh_exchange` | `true`  | Exchange SSH keys |

### Time

| Variable           | Default          | Description |
|--------------------|------------------|-------------|
| `node_timezone`    | `Asia/Hong_Kong` | Timezone    |
| `node_ntp_servers` | `[]`             | NTP servers |

### VIP

| Variable        | Default | Description           |
|-----------------|---------|-----------------------|
| `vip_enabled`   | `false` | Enable keepalived VIP |
| `vip_address`   | (none)  | VIP address with CIDR |
| `vip_interface` | `eth0`  | Network interface     |

Full parameter list: [NODE Configuration](https://pigsty.io/docs/node/config)


## See Also

- [`node_id`](../node_id): Node identity derivation
- [`node_monitor`](../node_monitor): Node monitoring setup
- [`node_remove`](../node_remove): Remove node components
- [`haproxy`](../haproxy): Load balancer setup
