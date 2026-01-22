# Role: juice

Deploy JuiceFS distributed filesystem with PostgreSQL backend.

## Quick Start

```yaml
juice_cache: /data/juice
juice_instances:
  pgfs:
    path: /pgfs
    meta: postgres://dbuser_meta:DBUser.Meta@10.10.10.10:5432/meta
    data: --storage postgres --bucket 10.10.10.10:5432/meta
    port: 9567
  data:
    path: /data/shared
    meta: postgres://dbuser_meta:DBUser.Meta@10.10.10.10:5432/meta
    data: --storage minio --bucket http://sss.pigsty:9000/juice
    port: 9568  # each instance needs a unique port!
```

```bash
./juice.yml -l <host>
```

## Variables

| Variable          | Default       | Description                |
|-------------------|---------------|----------------------------|
| `juice_cache`     | /data/juice   | Shared cache directory     |
| `juice_instances` | {}            | Dict of JuiceFS instances  |

### Instance Fields

| Field   | Required | Default          | Description                         |
|---------|----------|------------------|-------------------------------------|
| `path`  | Yes      | -                | Mountpoint                          |
| `meta`  | Yes      | -                | Metadata URL                        |
| `data`  | No       | ''               | Format options                      |
| `unit`  | No       | juicefs-\<name\> | Service name                        |
| `mount` | No       | ''               | Mount options                       |
| `port`  | No       | 9567             | Metrics port (unique per instance!) |
| `owner` | No       | root             | Mountpoint owner                    |
| `group` | No       | root             | Mountpoint group                    |
| `mode`  | No       | 0755             | Mountpoint mode                     |
| `state` | No       | create           | create or absent                    |

**Note**: Each instance on the same host must have a unique `port`. The playbook will fail if port conflicts are detected.

## Tags

| Tag            | Description                                       |
|----------------|---------------------------------------------------|
| juice_id       | Validate config and check port conflicts          |
| juice_install  | Install juicefs package                           |
| juice_cache    | Create cache directory                            |
| juice_clean    | Remove instances (state=absent)                   |
| juice_instance | Create instances (state=create)                   |
| juice_init     | Format filesystem                                 |
| juice_dir      | Create mountpoint                                 |
| juice_config   | Render service files (triggers restart on change) |
| juice_launch   | Start service                                     |
| juice_register | Register to prometheus                            |

## Usage

```bash
# Deploy all instances
./juice.yml -l <host>

# Deploy single instance
./juice.yml -l <host> -e fsname=pgfs

# Reconfigure (only restarts if config changed)
./juice.yml -l <host> -t juice_config

# Remove instance (set state: absent in config first)
./juice.yml -l <host>
```

## Files

| Path                                         | Description      |
|----------------------------------------------|------------------|
| /etc/default/juicefs-\<name\>                | Environment file |
| /etc/systemd/system/juicefs-\<name\>.service | Systemd unit     |
| \<juice_cache\>/                             | Cache directory  |
| \<path\>/                                    | Mountpoint       |
