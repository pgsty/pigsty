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
├── node_uv                    # Setup uv python venv
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

| Variable             | Default | Description                                                       |
|----------------------|---------|-------------------------------------------------------------------|
| `node_selinux_mode`  | `enum`  | set selinux mode: enforcing,permissive,disabled                   |
| `node_firewall_mode` | `enum`  | firewall mode: zone (default), off (disable), none (skip & self-managed) |


### Packages

| Variable            | Default | Description            |
|---------------------|---------|------------------------|
| `node_repo_modules` | `local` | Repo modules to enable |
| `node_packages`     | `[]`    | Packages to install    |

### UV Python

| Variable            | Default       | Description                            |
|---------------------|---------------|----------------------------------------|
| `node_uv_env`       | `/data/venv`  | uv venv path, empty string to skip     |
| `node_pip_packages` | `''`          | pip packages to install in venv        |

### Admin

| Variable                  | Default  | Description           |
|---------------------------|----------|-----------------------|
| `node_admin_enabled`      | `true`   | Create admin user     |
| `node_admin_username`     | `dba`    | Admin username        |
| `node_admin_uid`          | `88`     | Admin user UID/GID    |
| `node_admin_sudo`         | `nopass` | Sudo privilege mode   |
| `node_admin_ssh_exchange` | `true`   | Exchange SSH keys     |
| `node_admin_pk_current`   | `true`   | Add current user key  |
| `node_admin_pk_list`      | `[]`     | Extra SSH public keys |

**Sudo Modes** (`node_admin_sudo`):
- `nopass`: Full sudo without password (default)
- `all`: Full sudo with password required
- `limit`: Limited commands without password (systemctl, journalctl, cat, less, tail, head)

### Time

| Variable           | Default | Description              |
|--------------------|---------|--------------------------|
| `node_timezone`    | `''`    | Timezone (empty to skip) |
| `node_ntp_servers` | `[]`    | NTP servers              |

### Tuning

| Variable              | Default | Description               |
|-----------------------|---------|---------------------------|
| `node_tune`           | `oltp`  | Tuned profile to apply    |
| `node_hugepage_count` | `0`     | Number of 2MB hugepages   |
| `node_hugepage_ratio` | `0`     | Hugepage memory ratio     |
| `node_sysctl_params`  | `{fs.nr_open: 8388608}` | Extra sysctl parameters   |

**Tuned Profiles** (`node_tune`):
- `oltp`: Optimized for transaction processing (low latency, high throughput)
- `olap`: Optimized for analytical workloads (larger buffers, sequential I/O)
- `crit`: Balanced for critical workloads
- `tiny`: Minimal tuning for small/test systems
- `none`: Skip tuning

### VIP

| Variable        | Default  | Description                              |
|-----------------|----------|------------------------------------------|
| `vip_enabled`   | `false`  | Enable keepalived VIP                    |
| `vip_address`   | (none)   | VIP address with CIDR                    |
| `vip_vrid`      | (none)   | VRRP router ID (1-254)                   |
| `vip_role`      | `backup` | Initial role                             |
| `vip_preempt`   | `false`  | Enable VIP preemption                    |
| `vip_interface` | `eth0`   | Network interface                        |
| `vip_auth_pass` | `''`     | VRRP auth password (empty for auto)      |

> **Note**: VIP requires `vip_address` and `vip_vrid` to be set. Multiple nodes
> with the same `vip_address` form a VRRP cluster for automatic failover.
> If `vip_auth_pass` is empty, the default `<cluster>-<vrid>` will be used.

Full parameter list: [NODE Configuration](https://pigsty.io/docs/node/config)


## Platform Support

This role supports **RHEL/Rocky 8-10**, **Ubuntu 22-24**, and **Debian 12-13**.

Some features have OS-specific implementations:
- **THP Disable**: Handled by tuned profiles (cross-platform)
- **Static Network**: RHEL uses `/etc/sysconfig/`, Debian uses systemd-resolved
- **Firewall**: RHEL uses firewalld, Debian/Ubuntu uses ufw


## Security Considerations

The default configuration provides a baseline secure stance while keeping development convenient.
For production environments, review and adjust the following:

| Setting                     | Default         | Production Recommendation                   |
|-----------------------------|-----------------|---------------------------------------------|
| `node_admin_sudo`           | `nopass`        | Use `limit` or `all` for least privilege    |
| `node_selinux_mode`         | `permissive`    | Consider `enforcing` for critical systems   |
| `node_firewall_mode`        | `zone`          | Keep `zone`; use `none` only if self-managed |
| `node_firewall_public_port` | `[22, 80, 443]` | Add extra ports (e.g. 5432) only when required |
| `vip_auth_pass`             | auto-generated  | Set explicit strong password                |

**Recommended production settings**:

```yaml
node_admin_sudo: limit              # Limited sudo commands without password
node_selinux_mode: enforcing        # Full SELinux enforcement
node_firewall_mode: zone            # trust intranet, expose 22 80 443 only
node_firewall_public_port: [22, 80, 443]  # Minimal public exposure
vip_auth_pass: '<strong-secret>'    # Explicit VRRP authentication
```

**SSH Host Key Checking**: The admin user's SSH config disables `StrictHostKeyChecking`
for cluster operations. This is necessary for ansible but allows potential MITM attacks.
Ensure your network is trusted or use a bastion host.


## Firewall Management

`node_firewall_mode` defaults to `zone` (trusted intranet + restricted public ports). Re-apply firewall rules with: `./node.yml -l <target> -t node_firewall`

> **Note**: Firewall rules are **additive only**. To remove rules, use manual commands:

```bash
# RHEL/Rocky (firewalld)
firewall-cmd --zone=public --remove-port=5432/tcp && firewall-cmd --runtime-to-permanent

# Debian/Ubuntu (ufw)
ufw delete allow 5432/tcp
```


## See Also

- [`node_id`](../node_id): Node identity derivation
- [`node_monitor`](../node_monitor): Node monitoring setup
- [`node_remove`](../node_remove): Remove node components
- [`haproxy`](../haproxy): Load balancer setup
