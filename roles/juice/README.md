# Role: juice

> Deploy JuiceFS Multi-Instance Filesystem with PostgreSQL/S3 Backends

| **Module**        | [JUICE](https://pigsty.io/docs/juice) |
|-------------------|---------------------------------------|
| **Docs**          | https://pigsty.io/docs/juice          |
| **Related Roles** | `pgsql`, `infra`, `vibe`              |


## Overview

The `juice` role deploys and manages **multiple JuiceFS instances** on a node.

Requires **ansible-core 2.16+**. See the [four-node test report](TESTING.zh.md)
for the tested scenarios, results and limits.

It provides:

- Configuration validation (names, required fields, port, path, and unit conflicts)
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
| `juice.yml` | Deploy/manage JuiceFS instances |


## File Structure

```text
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

```text
juice
├── juice_id
├── juice_install
├── juice_cache
├── juice_clean
├── juice_instance
│   ├── juice_init
│   ├── juice_config
│   ├── juice_launch
│   └── juice_dir
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
| `owner` | No       | `root`           | Filesystem root owner (set after mount)    |
| `group` | No       | `root`           | Filesystem root group (set after mount)    |
| `mode`  | No       | `'0755'`         | Filesystem root mode (set after mount)     |
| `state` | No       | `create`         | `create` or `absent`                       |


## Usage

```bash
# manage all instances
./juice.yml -l <host>

# manage one instance only
./juice.yml -l <host> -e fsname=pgfs

# create/config/start only
./juice.yml -l <host> -t juice_instance

# remove instances marked as state=absent, and refresh monitoring targets
./juice.yml -l <host> -t juice_clean
```


## Monitoring Registration

The role writes metrics targets on infra nodes:

- `/infra/targets/juice/<inventory_hostname>.yml`

Each active instance contributes one scrape target at:

- `<inventory_hostname>:<instance.port>`

When no active (`state: create`) instances remain on the host, the target file is removed.
An undefined, null or empty `juice_instances` skips the host; removal requires explicit `state: absent`.


## Notes

- `juicefs format` is throttled (`throttle: 1`) to avoid concurrent metadata initialization.
- The instance name is the JuiceFS volume name: 3 to 63 characters of `[a-z0-9-]`.
- Running instances are never restarted by the playbook. To apply changed mount options, run `-t juice_config,juice_launch` (renders the unit and reloads systemd), then `systemctl restart juicefs-<name>`.
- Removal stops the service and unmounts. It never touches metadata, file data, or the local cache.
- A failed stop retains the unit and environment file for diagnosis. Release mount users before retrying cleanup; no forced lazy unmount is performed.
- A successful mount does not guarantee a working metrics endpoint or an available storage backend. Verify metrics and application I/O separately.
- Metadata URL is stored in `/etc/default/<unit>` and should be treated as sensitive.
