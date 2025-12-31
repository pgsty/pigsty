# Role: repo

> Build and Serve Local Software Repository

| **Module**        | [INFRA](https://pigsty.io/docs/infra)              |
|-------------------|----------------------------------------------------|
| **Docs**          | https://pigsty.io/docs/infra/repo                  |
| **Related Roles** | [`infra`](../infra), [`cache`](../cache)          |


## Overview

The `repo` role creates a local software repository for offline installation:

- Check for existing local repo
- Download packages from upstream if needed
- Clean up dirty/unwanted packages
- Create APT/YUM repository metadata
- Serve repository via Nginx

This enables:
- **Offline Installation**: No internet access required after setup
- **Faster Deployment**: Local packages are much faster than upstream
- **Version Control**: Consistent package versions across all nodes
- **Air-Gapped Support**: Perfect for secure/isolated environments


## Playbooks

| Playbook                       | Description                         |
|--------------------------------|-------------------------------------|
| [`infra.yml`](../../infra.yml) | Full infrastructure (includes repo) |


## File Structure

```
roles/repo/
├── defaults/
│   └── main.yml              # Default variables
├── meta/
│   └── main.yml              # Role metadata & dependencies
├── tasks/
│   ├── main.yml              # Entry point: check -> prepare/build -> nginx
│   ├── build.yml             # [repo_build] Download packages & create repo
│   └── nginx.yml             # [repo_nginx] Setup temporary Nginx server
└── templates/
    ├── nginx.conf.j2         # Nginx main configuration
    ├── default.conf.j2       # Nginx server block for repo
    └── index.html.j2         # Repo landing page (shown during install)
```


## Tags

### Tag Hierarchy

```
repo                           # Full role execution
│
├── repo_check                 # Check if repo already exists
│
├── repo_prepare               # Use existing repo if found
│
├── repo_build                 # Build repo from scratch (if not exists)
│   ├── repo_dir               # Create repo directories
│   ├── repo_upstream          # Configure upstream repos
│   │   ├── repo_remove        # Backup existing repo files
│   │   └── repo_add           # Add upstream repo definitions
│   ├── repo_url_pkg           # Download packages from URLs
│   ├── repo_cache             # Refresh package cache
│   ├── repo_boot_pkg          # Install bootstrap packages
│   ├── repo_pkg               # Download all required packages
│   └── repo_create            # Create repo metadata (+ cleanup)
│   └── repo_use               # Configure system to use built repo
│
└── repo_nginx                 # Setup temporary Nginx server
```


## Key Variables

### Repository Settings

| Variable        | Default                    | Description                          |
|-----------------|----------------------------|--------------------------------------|
| `repo_enabled`  | `true`                     | Enable local repo creation           |
| `repo_name`     | `pigsty`                   | Repository name                      |
| `repo_home`     | `/www`                     | Repo base directory (symlink)        |
| `repo_endpoint` | `http://${admin_ip}:80`    | Access URL for the repository        |
| `repo_remove`   | `true`                     | Remove existing upstream repo files  |
| `repo_modules`  | `infra,node,pgsql`         | Which modules to include in repo     |

> Note: `/www` is a symbolic link to `/data/nginx` for FHS compatibility.

### Package Sources

| Variable             | Default | Description                              |
|----------------------|---------|------------------------------------------|
| `repo_upstream`      | `[...]` | Upstream repo definitions (OS-specific)  |
| `repo_packages`      | `[...]` | Package list to download                 |
| `repo_extra_packages`| `[]`    | Additional packages to include           |
| `repo_url_packages`  | `[]`    | Direct URL downloads (binaries, etc.)    |


## Repository Structure

```
/www/                         # Symlink -> /data/nginx
└── pigsty/                   # repo_name
    ├── *.rpm                 # RPM packages (EL)
    ├── *.deb                 # DEB packages (Debian/Ubuntu)
    ├── repodata/             # YUM metadata (EL only)
    │   ├── repomd.xml
    │   ├── primary.xml.gz
    │   └── modules.yaml      # DNF module metadata (EL8/9)
    ├── Packages.gz           # APT metadata (Debian/Ubuntu)
    └── repo_complete         # Completion marker (MD5 checksums)
```


## Workflow

### First Run (No Existing Repo)

```
repo_check ─────► repo_build ─────────────────────────► repo_nginx
     │                │                                      │
     │                ├── repo_dir (create directories)      │
     │                ├── repo_upstream (add sources)        │
     │                ├── repo_url_pkg (download URLs)       │
     │                ├── repo_cache (refresh cache)         │
     │                ├── repo_boot_pkg (install tools)      │
     │                ├── repo_pkg (download packages)       │
     │                ├── repo_create (build metadata)       │
     │                └── repo_use (configure local repo)    │
     │                                                       │
     └─► repo_complete not found                    Start Nginx
```

### Subsequent Runs (Repo Exists)

```
repo_check ─────► repo_prepare ─────► repo_nginx
     │                 │                   │
     │                 │                   │
     └─► repo_complete found         Start Nginx if not running
                       │
              Configure local repo file
```


## Dirty Package Cleanup

When downloading packages from upstream repositories, some unwanted packages may be pulled in. 
These "dirty" packages are automatically cleaned up before creating repository metadata:

| Pattern           | Platform       | Reason                                      |
|-------------------|----------------|---------------------------------------------|
| `*.i686.rpm`      | EL7            | 32-bit packages from multilib repos         |
| `*i386.deb`       | Debian/Ubuntu  | 32-bit packages not needed on x86_64        |
| `patroni*3.0.4*`  | All            | Old version conflicts with newer patroni    |

These packages can cause:
- Package conflicts during installation
- Unnecessary disk space usage
- Confusion when multiple versions exist

The cleanup happens in the `repo_create` task before `createrepo_c` or `dpkg-scanpackages` is executed.


## Common Commands

```bash
# Full repo setup
./infra.yml -t repo

# Check and use existing repo only
./infra.yml -t repo_check,repo_prepare

# Force rebuild repo (even if exists)
# repo-build
./infra.yml -t repo_build -e repo_build=true

# Rebuild without downloading (use existing packages)
./infra.yml -t repo_build -e repo_packages=[] -e repo_url_packages=[]

# Only recreate repo metadata
./infra.yml -t repo_create

# Add upstream repo definitions
./infra.yml -t repo_upstream

# Download specific packages
./infra.yml -t repo_pkg -e repo_packages='["nginx","postgresql17"]'

# Setup/restart repo nginx
./infra.yml -t repo_nginx

# create offline package from the repo
./cache.yml
```



## See Also

- [`infra`](../infra): Infrastructure deployment
- [`cache`](../cache): Create offline package cache
- [`node`](../node): Node preparation (uses repo)
- [Offline Install](https://pigsty.io/docs/setup/offline): Offline installation guide
- [Repo Config](https://pigsty.io/docs/infra/repo): Detailed configuration guide
