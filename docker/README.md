# Pigsty Docker

Run Pigsty in Docker containers with full SystemD support.


## Overview

Two images are available for different use cases:

| Image         | Size   | State       | Use Case                           |
|---------------|--------|-------------|------------------------------------|
| `pigsty`      | ~800MB | Initialized | Customize config before deployment |
| `pigsty-full` | ~4GB   | Deployed    | Quick demo, instant PostgreSQL     |

**pigsty (base image)**
- Debian 13 (Trixie) with SystemD
- SSH enabled (root:pigsty)
- `pig` CLI and Ansible installed
- Pigsty source at `/root/pigsty`
- Config template: `conf/docker.yml`
- **You run**: `./configure && ./deploy.yml`

**pigsty-full**
- Everything from base, plus:
- Complete Pigsty deployment (INFRA + ETCD + PGSQL)
- PostgreSQL 17 with extensions
- Grafana, VictoriaMetrics, Nginx
- **Ready to use immediately**


## Quick Start

### Option 1: Base Image (Recommended)

Build and deploy with your own configuration:

```bash
cd docker

# Build base image
make build

# Run container
make run

# Enter container
make exec

# Inside container: configure and deploy
./configure -c docker -g -i 127.0.0.1
./deploy.yml
```

### Option 2: Full Image (Quick Demo)

Use pre-deployed image for instant access:

```bash
cd docker

# Build full image (takes longer)
make build-full

# Run container
make run-full

# Everything is ready!
```

### Option 3: Pull from Docker Hub

```bash
# Pull base image
make pull
make run

# Or pull full image
make pull-full
make run-full
```


## Build Process

### Building Base Image

```bash
make build                    # Build for current architecture
VERSION=v4.0.0 make build     # Specific version
```

Build steps:
1. Start from `debian:trixie`
2. Install SystemD, SSH, basic tools
3. Configure SystemD for container environment
4. Install `pig` CLI from Pigsty APT repo
5. Run `pig sty init` and `pig sty boot`
6. Copy `conf/docker.yml` as default config

### Building Full Image

```bash
make build-full               # Build for current architecture
```

Additional steps on top of base:
1. Run `pig sty conf -c docker -i 127.0.0.1`
2. Run `pig sty deploy` (full deployment)

### Multi-Architecture Build

Build for both amd64 and arm64, push to Docker Hub:

```bash
make build-multiarch          # Base image
make build-multiarch-full     # Full image
```

Requires `docker buildx` configured.


## Container Access

After starting the container:

| Service    | URL/Command                               | Credentials    |
|------------|-------------------------------------------|----------------|
| SSH        | `ssh root@localhost -p 2222`              | `pigsty`       |
| Web Portal | http://localhost:8080                     | -              |
| Grafana    | http://localhost:8080/grafana             | `admin:pigsty` |
| PostgreSQL | `psql -h localhost -p 5432 -U dbuser_dba` | `DBUser.DBA`   |

All web services are accessed through Nginx on port 80/443.


## Configuration

### Port Mapping

| Variable     | Default | Description |
|--------------|---------|-------------|
| `SSH_PORT`   | 2222    | SSH access  |
| `HTTP_PORT`  | 8080    | Nginx HTTP  |
| `HTTPS_PORT` | 8443    | Nginx HTTPS |
| `PG_PORT`    | 5432    | PostgreSQL  |

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

### Container Lifecycle

```bash
make run          # Start base image container
make run-full     # Start full image container
make start        # Start stopped container
make stop         # Stop container
make restart      # Restart container
make clean        # Stop and remove container
```

### Container Access

```bash
make exec         # Bash into container
make ssh          # SSH into container
make log          # View container logs
make status       # SystemD status
make pass         # Show passwords
make conf         # Show pigsty.yml
```

### Image Management

```bash
make build        # Build base image
make build-full   # Build full image
make pull         # Pull from Docker Hub
make push         # Push to Docker Hub
make save         # Export to tarball
make load         # Import from tarball
make rmi          # Remove image
```


## Architecture Support

Auto-detected from host:
- `x86_64` → `amd64`
- `aarch64` / `arm64` → `arm64`

Other architectures are not supported.


## Offline Transfer

Export image to tarball for air-gapped environments:

```bash
make save                     # -> pigsty-v4.0.0-arm64.tgz
# Transfer file to target machine
make load                     # Import on target
```


## Requirements

- Docker 20.10+ with privileged container support
- 4GB+ RAM recommended
- 20GB+ disk for full image
- Linux or macOS (with Docker Desktop)


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

Try running Docker with root privileges, or ensure cgroup v2 is properly configured on the host.

### Port already in use

Use different port mappings:

```bash
PG_PORT=15432 HTTP_PORT=8888 make run
```


---

## Release Guide

This section is for maintainers who build and publish official Pigsty Docker images.

### Image Matrix

For each Pigsty release (e.g., `v4.0.0`), we publish **4 images**:

| Image                | Architecture      | Description                     |
|----------------------|-------------------|---------------------------------|
| `pigsty:v4.0.0`      | `amd64` + `arm64` | Base image, multi-arch manifest |
| `pigsty-full:v4.0.0` | `amd64` + `arm64` | Full image, multi-arch manifest |

With Docker multi-arch manifests, users can pull with a single tag and Docker automatically selects the correct architecture.

### Tag Naming Convention

```
pgsty/pigsty:<version>           # Base image (e.g., pgsty/pigsty:v4.0.0)
pgsty/pigsty:latest              # Base image, latest version
pgsty/pigsty-full:<version>      # Full image (e.g., pgsty/pigsty-full:v4.0.0)
pgsty/pigsty-full:latest         # Full image, latest version
```

### Building Images

#### Prerequisites

1. Docker with buildx enabled
2. Login to Docker Hub: `docker login`
3. Create buildx builder (if not exists):

```bash
docker buildx create --name pigsty-builder --use
docker buildx inspect --bootstrap
```

#### Build & Push Multi-Arch Images (Recommended)

Build both architectures and push to Docker Hub in one command:

```bash
cd docker

# Build and push base image (amd64 + arm64)
make build-multiarch

# Build and push full image (amd64 + arm64)
make build-multiarch-full
```

This runs:
```bash
# Base image
docker buildx build --platform linux/amd64,linux/arm64 \
    --target base \
    -t pgsty/pigsty:v4.0.0 \
    -t pgsty/pigsty:latest \
    --push .

# Full image
docker buildx build --platform linux/amd64,linux/arm64 \
    --target full \
    -t pgsty/pigsty-full:v4.0.0 \
    -t pgsty/pigsty-full:latest \
    --push .
```

#### Build Single Architecture (for testing)

```bash
# Build for current architecture only
make build           # Base image -> pigsty:v4.0.0
make build-full      # Full image -> pigsty-full:v4.0.0

# Specify version
VERSION=v4.0.0 make build
VERSION=v4.0.0 make build-full
```

### Publishing to Docker Hub

#### Option A: Multi-Arch (Recommended)

```bash
# This builds AND pushes in one step
make build-multiarch
make build-multiarch-full
```

#### Option B: Single Architecture

If you need to push single-arch images:

```bash
# Build locally
make build
make build-full

# Tag and push
make push           # Push base image
make push-full      # Push full image
```

### Complete Release Workflow

```bash
cd docker

# 1. Set version
export VERSION=v4.0.0

# 2. Login to Docker Hub
docker login

# 3. Ensure buildx builder exists
docker buildx create --name pigsty-builder --use 2>/dev/null || true
docker buildx inspect --bootstrap

# 4. Build and push base image (both architectures)
make build-multiarch

# 5. Build and push full image (both architectures)
make build-multiarch-full

# 6. Verify images on Docker Hub
docker manifest inspect pgsty/pigsty:${VERSION}
docker manifest inspect pgsty/pigsty-full:${VERSION}
```

### Verify Published Images

```bash
# Check multi-arch manifest
docker manifest inspect pgsty/pigsty:v4.0.0

# Pull and test on different architectures
docker pull pgsty/pigsty:v4.0.0
docker run --rm pgsty/pigsty:v4.0.0 uname -m
```

### Offline Distribution

Export images for air-gapped environments:

```bash
# Save images to tarball (architecture-specific)
make save           # -> pigsty-v4.0.0-arm64.tgz
make save-full      # -> pigsty-full-v4.0.0-arm64.tgz

# On target machine, load images
make load
make load-full
```


---

## Common Operations

### Starting and Stopping

```bash
# Start container (first time)
make run              # Base image
make run-full         # Full image

# After container exists
make stop             # Stop container
make start            # Start stopped container
make restart          # Restart container

# Remove container
make clean            # Stop and remove
make rm               # Remove only (must be stopped)
```

### Entering the Container

```bash
# Via Docker exec (recommended)
make exec

# Via SSH
make ssh
# Or directly:
ssh root@localhost -p 2222   # Password: pigsty
```

### Viewing Logs and Status

```bash
make log              # Container logs (follow mode)
make status           # SystemD status inside container
make ps               # Process list inside container
```

### Configuration and Passwords

```bash
make pass             # Show passwords from pigsty.yml
make conf             # Show full pigsty.yml config
make ip               # Show container IP address
```

### Inspecting the Container

```bash
make inspect          # Full container details (JSON)
make top              # Running processes
```

### Custom Port Mapping

```bash
# Change default ports
SSH_PORT=2022 make run
HTTP_PORT=80 make run
PG_PORT=15432 make run

# Multiple overrides
SSH_PORT=2022 HTTP_PORT=80 PG_PORT=15432 make run
```

### Custom Data Directory

```bash
# Use custom data volume
DATA=/mnt/pigsty make run

# The /data directory inside container maps to this path
```

### Rebuild from Scratch

```bash
# Stop, remove container, rebuild image, start new container
make rebuild

# Or step by step:
make clean            # Remove existing container
make build            # Rebuild image
make run              # Start fresh container
```

### Debugging

```bash
# Run interactive shell without SystemD
make shell

# Test with plain Debian image
make test
```
