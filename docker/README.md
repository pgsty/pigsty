# Pigsty Docker

Run Pigsty in Docker containers with full systemd support.

Works on both **macOS** (Docker Desktop) and **Linux**.

- Docker Hub: https://hub.docker.com/r/pgsty/pigsty
- Documentation: https://pigsty.io/docs/docker
- GitHub: https://github.com/pgsty/pigsty

------

## Quick Start

You can launch pigsty with the [`docker-compose.yml`](docker-compose.yml), pull from DockerHub:

```bash
cd ~/pigsty/docker; make launch
```

Or build on your own machine first

```bash
cd ~/pigsty/docker; make build
```

------

## Configuration

And you can specify pigsty image name & tag with [`PIGSTY_IMAGE`](#image-variants) and  `PIGSTY_VERSION`
,and configure ports and version in the [`.env`](.env) file:

| Variable            | Default  | Container | Description |
|---------------------|----------|-----------|-------------|
| `PIGSTY_SSH_PORT`   | 2222     | 22        | SSH access  |
| `PIGSTY_HTTP_PORT`  | 8080     | 80        | Nginx HTTP  |
| `PIGSTY_HTTPS_PORT` | 8443     | 443       | Nginx HTTPS |
| `PIGSTY_PG_PORT`    | 5432     | 5432      | PostgreSQL  |

------

## Image Variants

| Image          | Pull   | Size  | Contents                    | Use Case        |
|----------------|--------|-------|-----------------------------|-----------------|
| `pgsty/linux`  | ~150MB | 400MB | Debian 13 + systemd + SSH   | Base container  |
| `pgsty/admin`  | ~500MB | 1.3GB | + pig + Ansible + packages  | **Admin node**  |
| `pgsty/infra`  | ~1.0GB | 2.7GB | + monitoring stack          | Infra node      |
| `pgsty/pgsql`  | ~1.2GB | 3.1GB | + PostgreSQL 18 core        | PGSQL node      |
| `pgsty/pigsty` | ~1.6GB | 4.3GB | + all 340 extensions        | **Full Deploy** |

- **Pull**: Compressed transfer size when pulling from Docker Hub
- **Size**: Uncompressed disk size after pulling
- All images support **amd64** (x86_64) and **arm64** (Apple Silicon, AWS Graviton)
- Tag are same as pigsty version: `v4.0.0`, or `latest`

> Web Portal & PostgreSQL are available after **Deployment** (`./deploy.yml`)
 

------

## Accessing Services

| Service    | URL / Command                                                    | Credentials        |
|------------|------------------------------------------------------------------|--------------------|
| SSH        | `ssh root@localhost -p 2222`                                     | `pigsty`           |
| Web Portal | http://localhost:8080                                            | -                  |
| Grafana    | http://localhost:8080/ui                                         | `admin` / `pigsty` |
| PostgreSQL | `psql postgres://dbuser_dba:DBUser.DBA@localhost:5432/postgres`  | `DBUser.DBA`       |

> Web Portal & PostgreSQL are available after **Deployment** (`./deploy.yml`)


------

## Commands Reference

### Docker Compose (Recommended)

```bash
make up           # Start container
make down         # Stop and remove
make exec         # Enter container
make config       # Run ./configure
make deploy       # Run ./deploy.yml
make launch       # up + config + deploy
```

### Build Images

```bash
make linux        # Base Debian + systemd
make admin        # + pig + Ansible + packages
make infra        # + monitoring stack
make pgsql        # + PostgreSQL core
make pigsty       # + all extensions
make images       # Build all 5 images
```

### Push Images

```bash
make pigsty-push  # Push pgsty/pigsty (multi-arch)
make images-push  # Push all images
```

### Alternative (docker run)

```bash
make run          # Run with docker run
make clean        # Stop and remove
make purge        # Remove + delete data
```

### Container Access

```bash
make exec         # Bash into container
make ssh          # SSH into container
make log          # View logs
make status       # systemd status
make ps           # Process list
```


------

## Building

```bash
make linux        # build pgsty/linux stage image
make admin        # build pgsty/admin stage image
make infra        # build pgsty/infra stage image
make pgsql        # build pgsty/pgsql stage image
make pigsty       # build pgsty/pigsty stage image
make images       # Build all 5 images
make images-push  # Push all images
```

```bash
debian:trixie
    └── linux   (base + systemd + ssh)
        └── admin   (+ pig + ansible + packages)
            └── infra   (+ monitoring stack)
                └── pgsql   (+ postgresql core)
                    └── pigsty (+ all extensions)
```


------

## Manual Run

If you prefer `docker run` over `docker compose`:

```bash
mkdir -p /data/pigsty    # create data directory
docker run -d --privileged --name pigsty \
  -p 2222:22 -p 8080:80 -p 5432:5432 \
  -v /data/pigsty:/data \
  pgsty/pigsty:v4.0.0
docker exec -it pigsty /bin/bash
./configure -c docker -g --ip 127.0.0.1
./deploy.yml
```

------

## Requirements

- Docker 20.10+ (Docker Linux / Docker Desktop on macOS)
- At least 1 vCPU  / 2GB+ RAM
- 20GB+ disk space

