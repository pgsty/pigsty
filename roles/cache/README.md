# Role: cache

> Create Offline Package Cache Tarball for Distribution

| **Module**        | [INFRA](https://pigsty.io/docs/infra)  |
|-------------------|----------------------------------------|
| **Docs**          | https://pigsty.io/docs/setup/offline   |
| **Related Roles** | [`repo`](../repo), [`infra`](../infra) |


## Overview

The `cache` role creates an **offline package tarball** from an existing local repository:

- Verify repository directories exist and are populated
- Trim trashes and recreate YUM/APT metadata
- Create compressed tarball of all packages
- Fetch tarball to control node for distribution

This is used to create portable offline installation packages.


## Playbooks

This role is typically invoked via make target:

```bash
make cache    # Create offline package cache
./cache.yml   # Playbook to create offline package
```


## File Structure

```
roles/cache/
├── defaults/
│   └── main.yml              # Default variables
├── meta/
│   └── main.yml              # Role dependencies
└── tasks/
    └── main.yml              # Cache creation logic
```


## Tags

### Tag Hierarchy

```
cache (full role)
│
├── cache_id                   # Calculate package names
│
├── cache_check                # Verify repo directories exist
│
├── cache_create               # Recreate repo metadata
│
├── cache_tgz                  # Create compressed tarball
│
└── cache_fetch                # Fetch tarball to control node
```


## Key Variables

| Variable         | Default                                   | Description      |
|------------------|-------------------------------------------|------------------|
| `cache_pkg_name` | `pigsty-pkg-${version}.${os}.${arch}.tgz` | Output filename  |
| `cache_pkg_dir`  | `dist/${version}`                         | Output directory |
| `cache_repo`     | `pigsty`                                  | Repo names (CSV) |


## Output

The cache tarball is created at:

```
dist/<version>/pigsty-pkg-<version>.<os>.<arch>.tgz
```

Examples:
- `dist/v4.0.0/pigsty-pkg-v4.0.0.el9.x86_64.tgz`
- `dist/v4.0.0/pigsty-pkg-v4.0.0.u22.x86_64.tgz`
- `dist/v4.0.0/pigsty-pkg-v4.0.0.d12.aarch64.tgz`


## Workflow

1. **cache_check**: Verify `/data/pigsty` is not empty
2. **cache_create**: Run `createrepo_c` (RPM) or `dpkg-scanpackages` (DEB)
3. **cache_tgz**: Create `/tmp/pkg.tgz` on remote node
4. **cache_fetch**: Download to local `dist/` directory


## Using the Cache

To use the offline package:

```bash
# Extract to /data on target node
tar -xzf pigsty-pkg-v4.0.0.el9.x86_64.tgz -C /data

# Or use during bootstrap
./bootstrap -p /path/to/pigsty-pkg-*.tgz
```


## See Also

- [`repo`](../repo): Build local repository
- [Offline Installation](https://pigsty.io/docs/setup/offline): Offline setup guide
