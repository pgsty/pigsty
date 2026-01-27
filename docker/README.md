# Pigsty Docker

Run Pigsty in Docker containers with full systemd support.

- Docker Hub: https://hub.docker.com/r/pgsty/pigsty
- Documentation: https://pigsty.io/docs/setup
- GitHub: https://github.com/pgsty/pigsty
- Extension list: https://pgext.cloud/list

## Overview

The `pgsty/pigsty` Docker image provides a ready-to-deploy environment:

- **Base Image**: Debian 13 (Trixie) with Systemd
- **PostgreSQL**: Version 18 with 340+ extensions available
- **Monitoring**: Grafana, VictoriaMetrics, VictoriaLogs, Nginx
- **HA Stack**: Patroni, etcd, HAProxy, pgBackRest
- **Tools**: `pig` CLI, Ansible, psql, pgbench

After starting, run `./configure && ./deploy.yml` to deploy.



## Quick Start

### Docker Compose

```bash
make launch     # up, configure, deploy in one step
```

Which is equivalent to:

```bash
docker compose up -d              # make up
docker compose exec pigsty bash   # make exec
./configure -c docker -g -i 127.0.0.1
./deploy.yml
```

### Build and Run

```bash
cd docker
make build    # Build image
make run      # Run container
make exec     # Enter container

# Inside container
./configure -c docker -g -i 127.0.0.1
./deploy.yml
```


## Container Access

After deployment:

| Service    | URL / Command                             | Credentials        |
|------------|-------------------------------------------|--------------------|
| SSH        | `ssh root@localhost -p 2222`              | `pigsty`           |
| Web Portal | http://localhost:8080                     | -                  |
| Grafana    | http://localhost:8080/ui                  | `admin` / `pigsty` |
| PostgreSQL | `psql -h localhost -p 5432 -U dbuser_dba` | `DBUser.DBA`       |

### Default Users

| User           | Password           | Purpose            |
|----------------|--------------------|--------------------|
| `dbuser_dba`   | `DBUser.DBA`       | Database admin     |
| `dbuser_meta`  | `DBUser.Meta`      | Application user   |
| `dbuser_view`  | `DBUser.Viewer`    | Read-only access   |


## Configuration

### Port Mapping

| Variable     | Default | Container | Description |
|--------------|---------|-----------|-------------|
| `SSH_PORT`   | 2222    | 22        | SSH access  |
| `HTTP_PORT`  | 8080    | 80        | Nginx HTTP  |
| `HTTPS_PORT` | 8443    | 443       | Nginx HTTPS |
| `PG_PORT`    | 5432    | 5432      | PostgreSQL  |

Override with environment variables:

```bash
SSH_PORT=2022 HTTP_PORT=80 PG_PORT=15432 make run
```

### Data Volume

```bash
DATA=/mnt/pigsty make run     # Custom data path
```

The `/data` directory inside container is mounted from host.


## Commands Reference

### Docker Compose (Recommended)

```bash
make up           # Create and start container
make down         # Stop and remove container
make start        # Start stopped container
make stop         # Stop running container
make restart      # Restart container
make pull         # Pull latest image from Docker Hub
make config       # Run ./configure -c docker -g
make deploy       # Run ./deploy.yml
make launch       # up + config + deploy (one-liner)
```

### Alternative (docker run)

```bash
make run          # Run container with docker run
make clean        # Stop and remove container
make purge        # Remove container AND data (dangerous!)
```

### Container Access

```bash
make exec         # Bash into container
make ssh          # SSH into container
make log          # View container logs
make status       # SystemD status
make ps           # Process list
make pass         # Show passwords
make conf         # Show pigsty.yml
```

### Image Management

```bash
make build        # Build image locally
make push         # Build & push multi-arch image
make save         # Export to tarball
make load         # Import from tarball
make rmi          # Remove image
```


## Build Process

```bash
make build                    # Build for current architecture
VERSION=v4.0.0 make build     # Specific version
```

Build steps:
1. Start from `debian:trixie`
2. Install SystemD, SSH, essential tools
3. Configure SystemD for container environment
4. Install `pig` CLI from Pigsty APT repo
5. Run `pig sty init` and `pig sty boot`
6. Apply `conf/docker.yml` as default config


## Architecture Support

Auto-detected from host:
- `x86_64` → `amd64`
- `aarch64` / `arm64` → `arm64`


## Offline Transfer

Export image for air-gapped environments:

```bash
make save         # -> pigsty-v4.0.0-arm64.tgz
make load         # Import on target machine
```


## Requirements

- Docker 20.10+ with privileged container support
- 4GB+ RAM (8GB recommended)
- 20GB+ disk space
- Linux or macOS (Docker Desktop)


## Troubleshooting

### Container exits immediately

SystemD requires privileged mode and cgroup access:

```bash
docker run -d --privileged \
  --cgroupns=host \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  pigsty:v4.0.0
```

### Permission denied on cgroup

Ensure cgroup v2 is properly configured, or run Docker with root privileges.

### Port already in use

```bash
PG_PORT=15432 HTTP_PORT=8888 make run
```


## Resources

- **Documentation**: https://pigsty.io/docs
- **Configuration**: https://pigsty.io/docs/conf
- **Extensions**: https://pigsty.io/ext
- **GitHub**: https://github.com/pgsty/pigsty
- **Docker Hub**: https://hub.docker.com/r/pgsty/pigsty
