# Role: juice

> Deploy JuiceFS Multi-Instance Filesystem with PostgreSQL/MinIO Backends

| **Module**        | [JUICE](https://pigsty.io/docs/juice)                     |
|-------------------|-----------------------------------------------------------|
| **Docs**          | https://pigsty.io/docs/juice                              |
| **Related Roles** | [`pgsql`](../pgsql), [`infra`](../infra), [`vibe`](../vibe) |


## Overview

The `juice` role deploys and manages **multiple JuiceFS instances** on a node.

It provides:

- Configuration validation (`juice_instances` must be a dict)
- Port conflict detection across JuiceFS instances
- `juicefs` package installation
- Shared cache directory initialization
- Instance lifecycle management (`create` / `absent`)
- Metrics target registration to infra monitoring

Each instance is managed as an independent systemd unit:

- Environment file: `/etc/default/<unit>`
- Service file: `/etc/systemd/system/<unit>.service`
- Mountpoint: user-defined `path`


## Playbooks

| Playbook                     | Description                     |
|------------------------------|---------------------------------|
| [`juice.yml`](../../juice.yml) | Deploy/manage JuiceFS instances |


## File Structure

```
roles/juice/
├── defaults/
│   └── main.yml              # Default variables and schema notes
├── meta/
│   └── main.yml              # Role metadata
├── tasks/
│   ├── main.yml              # Entry point
│   ├── instance.yml          # Create/start one instance
│   └── clean.yml             # Remove one instance
└── templates/
    ├── juice.env             # Per-instance metadata URL
    └── juice.svc             # Per-instance systemd unit
```


## Tags

### Tag Hierarchy

```
juice
├── juice_id
├── juice_install
├── juice_cache
├── juice_clean
├── juice_instance
│   ├── juice_init
│   ├── juice_dir
│   ├── juice_config
│   └── juice_launch
└── juice_register
```


## Key Variables

| Variable          | Default       | Description                               |
|-------------------|---------------|-------------------------------------------|
| `juice_cache`     | `/data/juice` | Shared cache directory for all instances  |
| `juice_instances` | `{}`          | Instance map (`name -> config`)           |
| `fsname`          | (unset)       | Optional CLI filter for single instance   |

### Instance Fields (`juice_instances.<name>`)

| Field   | Required | Default          | Description                                |
|---------|----------|------------------|--------------------------------------------|
| `path`  | Yes      | -                | Mountpoint path                            |
| `meta`  | Yes      | -                | JuiceFS metadata URL                       |
| `data`  | No       | `''`             | `juicefs format` extra options             |
| `unit`  | No       | `juicefs-<name>` | systemd unit name                          |
| `mount` | No       | `''`             | Extra mount options                        |
| `port`  | No       | `9567`           | Metrics port (must be unique on same host) |
| `owner` | No       | `root`           | Mountpoint owner                           |
| `group` | No       | `root`           | Mountpoint group                           |
| `mode`  | No       | `'0755'`         | Mountpoint mode                            |
| `state` | No       | `create`         | `create` or `absent`                       |


## Usage

```bash
# manage all instances
./juice.yml -l <host>

# manage one instance only
./juice.yml -l <host> -e fsname=pgfs

# create/config/start only
./juice.yml -l <host> -t juice_instance

# remove instances marked as state=absent
./juice.yml -l <host> -t juice_clean
```


## Monitoring Registration

The role writes metrics targets on infra nodes:

- `/infra/targets/juice/<inventory_hostname>.yml`

Each active instance contributes one scrape target at:

- `<inventory_hostname>:<instance.port>`


## Notes

- `juicefs format` is throttled (`throttle: 1`) to avoid concurrent metadata initialization.
- Metadata URL is stored in `/etc/default/<unit>` and should be treated as sensitive.
