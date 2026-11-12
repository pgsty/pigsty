# Pigsty Docker

Run Pigsty in Docker containers with full systemd support.

Works on both **macOS** (Docker Desktop) and **Linux**.

- Docker Hub: https://hub.docker.com/r/pgsty/pigsty
- Documentation: https://pigsty.io/docs/docker
- GitHub: https://github.com/pgsty/pigsty

------

## Quick Start

Make sure the default host ports (2222/8080/8443/5432) are available. otherwise, edit the [`.env`](.env) first.
Then run the following commands to launch Pigsty in Docker:

```bash
cd ~/pigsty/docker    # enter this dir 
make launch           # = make up config deploy
```

From a Pigsty Git checkout, you can also build the container image first (based on Debian 13.7):

```bash
cd ~/pigsty/docker
make build launch     # build image rather than pull
```

------

## Image

| Image          | Pull   | Size  | Contents                                  |
|----------------|--------|-------|-------------------------------------------|
| `pgsty/pigsty` | ~500MB | 1.3GB | Debian 13.7 + systemd + SSH + PIG 1.11.0 + Ansible |

- Supports **amd64** (x86_64) and **arm64** (Apple Silicon, AWS Graviton)
- Tags match pigsty version: `v4.6.0`, `latest`
- Configuration pre-generated with docker template
- Ready to deploy with `./deploy.yml`

The Debian 13.7 base is pinned to the multi-platform index of the
[`trixie-20261104` build](https://hub.docker.com/layers/library/debian/trixie-20261104/images/sha256-bfc36aecdece0387418759dba474aa856c026ca8087da3606b41b90ab0509c99),
checked on 2026-11-12. `make test` uses the same base image as the Dockerfile.

Pigsty v4.6.0 uses PostgreSQL 18.7 as its release baseline. PostgreSQL is installed
from the configured package repositories when `deploy.yml` runs; the base image
contains the deployment tools and source.

> Web Portal & PostgreSQL are available after **Deployment** (`./deploy.yml`)

------

## Configuration

Configure ports via environment variables or [`.env`](.env) file:

| Variable            | Default  | Container | Description |
|---------------------|----------|-----------|-------------|
| `PIGSTY_VERSION`    | v4.6.0   | -         | Image tag   |
| `PIGSTY_SSH_PORT`   | 2222     | 22        | SSH access  |
| `PIGSTY_HTTP_PORT`  | 8080     | 80        | Nginx HTTP  |
| `PIGSTY_HTTPS_PORT` | 8443     | 443       | Nginx HTTPS |
| `PIGSTY_PG_PORT`    | 5432     | 5432      | PostgreSQL  |

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
make config       # Run ./configure (optional)
make deploy       # Run ./deploy.yml
make launch       # up + deploy
```

### Build Image

```bash
make build        # Build image locally
make buildnc      # Build without cache
make push         # Build and push multi-arch image
```

Builds require a Git checkout, Git, and GNU tar (`brew install gnu-tar` on macOS).
Each build runs `bin/release` to package tracked source from the current working
tree, including local edits, into the ignored `pigsty.tgz` build input. Add new
source files to Git before building. The Docker context includes only this
archive and the Dockerfile; local runtime data and PKI files are excluded.

The default versions are `VERSION=v4.6.0` and `PIG_VERSION=1.11.0`. `VERSION`
must match the source checkout (a prerelease suffix is allowed), while `TAG`
can name a development image independently:

```bash
make build TAG=dev
```

Pull request CI uses the same source packaging step, so it can build a candidate
before its release tarball is published. For a direct Docker build, run
`make source` first and pass matching `VERSION` (without `v`) and `PIG_VERSION`
build arguments when overriding the defaults.

### Alternative (docker run)

```bash
make run          # Run with docker run
make clean        # Stop and remove
make purge        # Remove + delete ./data
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

## Manual Run

If you prefer `docker run` over `docker compose`:

```bash
mkdir -p ./data
docker run -d --privileged --name pigsty \
  -p 2222:22 -p 8080:80 -p 5432:5432 \
  -v ./data:/data \
  pgsty/pigsty:v4.6.0

docker exec -it pigsty ./configure -c docker -g --ip 127.0.0.1
docker exec -it pigsty ./deploy.yml
```

------

## Requirements

- Docker 20.10+ (Docker Engine on Linux / Docker Desktop on macOS)
- At least 1 vCPU / 2GB+ RAM
- 20GB+ disk space
