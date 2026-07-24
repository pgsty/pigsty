# Role: docker

> Deploy Docker Container Runtime

| **Module**        | [DOCKER](https://pigsty.io/docs/docker) |
|-------------------|-----------------------------------------|
| **Docs**          | https://pigsty.io/docs/docker/          |
| **Related Roles** | `node`, `infra`                         |


## Overview

The `docker` role installs **Docker** container runtime on nodes:

- Install Docker CE and docker-compose plugin
- Add admin user to docker group
- Create data directory
- Configure Docker daemon (registry mirrors, storage driver)
- Launch Docker service
- Register to monitoring
- Load cached Docker images (optional)

Docker is used to run stateless applications alongside Pigsty.


## Playbooks

| Playbook     | Description   |
|--------------|---------------|
| `docker.yml` | Deploy Docker |


## File Structure

```
roles/docker/
├── defaults/
│   └── main.yml              # Default variables
├── meta/
│   └── main.yml              # Role dependencies
├── tasks/
│   └── main.yml              # Main task list
└── templates/
    └── daemon.json.j2        # Docker daemon config
```


## Tags

### Tag Hierarchy

```
docker (full role)
│
├── docker_install             # Install Docker packages
│
├── docker_admin               # Add admin to docker group
│
├── docker_dir                 # Create data directory
│
├── docker_config              # Configure daemon.json
│
├── docker_launch              # Start Docker service
│
├── docker_register            # Register to monitoring
│   └── add_metrics            # Add Victoria targets
│
└── docker_image               # Load Docker images
```


## Key Variables

### Basic Configuration

| Variable               | Default            | Description                    |
|------------------------|--------------------|--------------------------------|
| `docker_enabled`       | `false`            | Enable Docker on this node     |
| `docker_data`          | `/data/docker`     | Docker data directory          |

### Storage & Runtime

| Variable                | Default    | Description                         |
|-------------------------|------------|-------------------------------------|
| `docker_storage_driver` | `overlay2` | Storage driver (overlay2/zfs/btrfs) |
| `docker_cgroups_driver` | `systemd`  | Cgroup driver (systemd/cgroupfs)    |

### Registry

| Variable                  | Default | Description                    |
|---------------------------|---------|--------------------------------|
| `docker_registry_mirrors` | `[]`    | Registry mirror URLs           |

### Monitoring

| Variable               | Default | Description                    |
|------------------------|---------|--------------------------------|
| `docker_exporter_port` | `9323`  | Docker metrics exporter port   |

### Images

| Variable             | Default             | Description                    |
|----------------------|---------------------|--------------------------------|
| `docker_image`       | `[]`                | Images to pull after install   |
| `docker_image_cache` | `/tmp/docker/*.tgz` | Local image cache glob pattern |


## Enabling Docker

Docker is disabled by default. Enable per-node or per-cluster:

```yaml
# Enable for specific node
infra:
  hosts:
    10.10.10.10:
      docker_enabled: true

# Enable for entire cluster
infra:
  vars:
    docker_enabled: true
```


## Registry Mirrors

Configure registry mirrors for faster pulls:

```yaml
docker_registry_mirrors:
  - https://mirror.gcr.io
  - https://registry.docker-cn.com
```


## Pre-loading Images

### Pull from Registry

```yaml
docker_image:
  - grafana/grafana:latest
  - prom/prometheus:latest
```

### Load from Local Cache

Place `.tgz` image archives in `/tmp/docker/`:

```bash
# Save image to cache
docker save grafana/grafana:latest | gzip > /tmp/docker/grafana.tgz
```


## Daemon Configuration

The role generates `/etc/docker/daemon.json`:

```json
{
  "data-root": "/data/docker",
  "exec-opts": ["native.cgroupdriver=systemd"],
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": { "max-size": "100m" },
  "metrics-addr": "<inventory-host>:9323",
  "experimental": true,
  "registry-mirrors": [],
  "default-ulimits": {
    "nofile": {
      "Hard": 1048576,
      "Soft": 1048576,
      "Name": "nofile"
    }
  },
  "max-concurrent-downloads": 8
}
```

When `proxy_env` is defined, the role also renders Docker's `proxies` block.


## See Also

- `node`: Node provisioning
- `infra`: Infrastructure deployment
- [Docker Guide](https://pigsty.io/docs/docker/): Configuration documentation
