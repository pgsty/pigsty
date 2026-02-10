# Role: cache

> Create Offline Package Cache Tarball for Distribution

| **Module**        | [INFRA](https://pigsty.io/docs/infra)  |
|-------------------|----------------------------------------|
| **Docs**          | https://pigsty.io/docs/setup/offline   |
| **Related Roles** | [`repo`](../repo), [`infra`](../infra) |


## Overview

The `cache` role creates an **offline package tarball** from an existing local repository:

- Verify repository directories exist and are populated
- Clean up dirty/unwanted packages to reduce size
- Recreate YUM/APT repository metadata
- Create compressed tarball of all packages
- Fetch tarball to control node for distribution

This enables:
- **Offline Installation**: Deploy Pigsty without internet access
- **Air-Gapped Environments**: Perfect for secure/isolated networks
- **Faster Deployment**: Skip package downloads on new installations
- **Version Consistency**: Same packages across all deployments


## Prerequisites

Before running the cache role:

1. **Pigsty must be installed** on the target node (infra node)
2. **Local repo must exist** at `{{ repo_home }}/{{ repo_name }}` (default: `/www/pigsty`)
3. **`rsync` must be installed** on both control and target nodes (for `synchronize` module)
4. The repo should contain all required packages (run `./infra.yml -t repo` first)


## Playbooks

| Playbook                       | Description                    |
|--------------------------------|--------------------------------|
| [`cache.yml`](../../cache.yml) | Create offline package tarball |

```bash
# Create offline package from infra node
./cache.yml -l infra

# Create from specific node
./cache.yml -l 10.10.10.10

# Using make target
make cache
```


## File Structure

```
roles/cache/
├── defaults/
│   └── main.yml              # Default variables
├── meta/
│   └── main.yml              # Role metadata & dependencies
├── tasks/
│   └── main.yml              # Cache creation logic
└── README.md                 # This documentation
```


## Tags

### Tag Hierarchy

```
cache                          # Full role execution
│
├── cache_id                   # Calculate output filename
│
├── cache_check                # Verify repo directories exist
│
├── cache_create               # Clean packages & recreate metadata
│
├── cache_tgz                  # Create compressed tarball
│
└── cache_fetch                # Fetch tarball to control node
```


## Key Variables

### Cache Settings

| Variable         | Default                                   | Description                            |
|------------------|-------------------------------------------|----------------------------------------|
| `cache_pkg_name` | `pigsty-pkg-${version}.${os}.${arch}.tgz` | Output filename pattern                |
| `cache_pkg_dir`  | `dist/${version}`                         | Output directory on control node       |
| `cache_repo`     | `pigsty`                                  | Repo names to cache (CSV for multiple) |

### Referenced Variables

| Variable    | Default        | Description                              |
|-------------|----------------|------------------------------------------|
| `version`   | `v4.1.0`       | Pigsty version string                    |
| `repo_home` | `/www`         | Repository base directory (symlink)      |
| `repo_name` | `pigsty`       | Repository name                          |

### Filename Placeholders

The `cache_pkg_name` supports these placeholders:

| Placeholder  | Example     | Description                |
|--------------|-------------|----------------------------|
| `${version}` | `v4.1.0`    | Pigsty version             |
| `${os}`      | `el9`, `u22`, `d12` | OS code from node_id |
| `${arch}`    | `x86_64`, `aarch64` | CPU architecture     |


## Output

### Tarball Location

The cache tarball is created at:

```
dist/<version>/pigsty-pkg-<version>.<os>.<arch>.tgz
```

### Examples by Platform

| Platform     | Output Filename                                 |
|--------------|-------------------------------------------------|
| EL9 x86_64   | `dist/v4.1.0/pigsty-pkg-v4.1.0.el9.x86_64.tgz`  |
| EL8 aarch64  | `dist/v4.1.0/pigsty-pkg-v4.1.0.el8.aarch64.tgz` |
| Ubuntu 22.04 | `dist/v4.1.0/pigsty-pkg-v4.1.0.u22.x86_64.tgz`  |
| Ubuntu 24.04 | `dist/v4.1.0/pigsty-pkg-v4.1.0.u24.x86_64.tgz`  |
| Debian 12    | `dist/v4.1.0/pigsty-pkg-v4.1.0.d12.x86_64.tgz`  |

### Tarball Contents

```
pigsty/                        # repo_name directory
├── *.rpm or *.deb             # Package files
├── repodata/                  # YUM metadata (RPM only)
│   ├── repomd.xml
│   ├── primary.xml.gz
│   └── modules.yaml           # DNF module metadata (EL8/9 only)
├── Packages.gz                # APT metadata (DEB only)
└── repo_complete              # MD5 checksums marker
```



## Dirty Package Cleanup

When building the cache, some unwanted packages are automatically removed to reduce tarball size and avoid conflicts:

| Pattern           | Platform | Reason                                       |
|-------------------|----------|----------------------------------------------|
| `*.i686.rpm`      | EL7      | 32-bit packages from multilib repos          |
| `*i386.deb`       | DEB      | 32-bit packages not needed on x86_64         |
| `patroni*3.0.4*`  | All RPM  | Old version conflicts with newer patroni     |
| `proj-data*`      | EL9+     | Large optional geospatial data (500MB+)      |
| `*docs*`          | All RPM  | Documentation packages (reduce size)         |

The cleanup happens in `cache_create` before metadata regeneration.


## DNF Module Metadata

For **EL8 and EL9 only**, DNF module metadata is generated:

```bash
repo2module -s stable . modules.yaml
modifyrepo_c --mdtype=modules modules.yaml repodata/
```

This is **not** executed on:
- EL7 (uses yum, not dnf modules)
- EL10+ (modulemd-tools not available)
- Debian/Ubuntu (uses APT, not DNF)


## Using the Cache

### Manual Extraction

```bash
# Extract to /www (repo_home) on target node
# /www is typically symlinked to /data/nginx
tar -xzf pigsty-pkg-v4.1.0.el9.x86_64.tgz -C /www

# Verify extraction
ls -la /www/pigsty/
```

### Bootstrap Installation (Recommended)

```bash
# Use offline package during bootstrap
./bootstrap -p /path/to/pigsty-pkg-v4.1.0.el9.x86_64.tgz

# or if your already put it to /tmp/pkg.tgz
./bootstrap   # /tmp/pkg.tgz is used by default

# Bootstrap will:
# 1. Extract tarball to /www/pigsty
# 2. Configure local repo
# 3. Install ansible and dependencies
```

### Offline Deployment Workflow

```bash
# On internet-connected build machine:
1. Install Pigsty normally:     ./bootstrap && ./configure && ./deploy.yml
2. Create offline package:      ./cache.yml -l infra

# Transfer tarball to air-gapped environment

# On air-gapped target machine:
3. Bootstrap with package:      ./bootstrap -p pigsty-pkg-*.tgz
4. Configure:                   ./configure
5. Install:                     ./deploy.yml
```


## Common Commands

```bash
# Full cache creation from infra nodes
./cache.yml -l infra

# Create cache from specific host
./cache.yml -l 10.10.10.10

# Only recreate repo metadata (skip fetch)
./cache.yml -l infra -t cache_create

# Only create tarball and fetch (skip metadata)
./cache.yml -l infra -t cache_tgz,cache_fetch

# Show cache info only
./cache.yml -l infra -t cache_info

# Specify custom version
./cache.yml -l infra -e version=v4.1.0

# Cache multiple repos
./cache.yml -l infra -e cache_repo=pigsty,minio
```



## See Also

- [`repo`](../repo): Build local repository (must run before cache)
- [`infra`](../infra): Full infrastructure deployment
- [Offline Installation](https://pigsty.io/docs/setup/offline): Complete offline setup guide
- [Bootstrap](https://pigsty.io/docs/setup/install/#bootstrap): Bootstrap process documentation
