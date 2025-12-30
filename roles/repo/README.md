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
- Create APT/YUM repository metadata
- Serve repository via Nginx

This enables:
- **Offline Installation**: No internet access required after setup
- **Faster Deployment**: Local packages are much faster
- **Version Control**: Consistent package versions across nodes


## Playbooks

| Playbook                       | Description                    |
|--------------------------------|--------------------------------|
| [`infra.yml`](../../infra.yml) | Full infrastructure (includes repo) |


## File Structure

```
roles/repo/
├── defaults/
│   └── main.yml              # Default variables
├── meta/
│   └── main.yml              # Role dependencies
├── tasks/
│   ├── main.yml              # Entry point
│   ├── build.yml             # [repo_build] Build repository
│   └── nginx.yml             # [repo_nginx] Serve via Nginx
└── templates/
    ├── nginx.conf.j2         # Nginx repo config
    └── ...
```


## Tags

### Tag Hierarchy

```
repo (full role)
│
├── repo_check                 # Check if repo exists
│
├── repo_prepare               # Use existing repo if found
│
├── repo_build                 # Build repo (if not exists)
│   ├── repo_upstream          # Add upstream repos
│   ├── repo_url_pkg           # Download URL packages
│   ├── repo_boot_pkg          # Install bootstrap packages
│   ├── repo_rpm_pkg           # Download RPM/DEB packages
│   └── repo_create            # Create repo metadata
│
└── repo_nginx                 # Serve via temp Nginx
```


## Key Variables

### Repository Settings

| Variable       | Default  | Description                |
|----------------|----------|----------------------------|
| `repo_enabled` | `true`   | Enable local repo          |
| `repo_name`    | `pigsty` | Repository name            |
| `repo_home`    | `/www`   | Repo base directory        |
| `repo_remove`  | `true`   | Remove existing repo files |

The `/www` is a soft link to `/data/nginx` for compatibility.

### Upstream Repositories

| Variable            | Default | Description                |
|---------------------|---------|----------------------------|
| `repo_upstream`     | `[...]` | Upstream repo definitions  |
| `repo_url_packages` | `[...]` | Direct URL downloads       |
| `repo_packages`     | `[...]` | Packages to download       |


## Repository Structure

```
/data/pigsty/
├── *.rpm / *.deb         # Package files
├── repodata/             # YUM metadata (RPM)
├── Packages.gz           # APT metadata (DEB)
└── repo_complete         # Completion flag file
```


## Workflow

### First Run (No Cache)

1. **repo_check**: Check for `/data/pigsty/repo_complete`
2. **repo_build**: Download and build repository
   - Install bootstrap packages (wget, nginx)
   - Add upstream repository definitions
   - Download all required packages
   - Create YUM/APT metadata
3. **repo_nginx**: Start temporary Nginx to serve repo

### Subsequent Runs (Cache Exists)

1. **repo_check**: Found existing repo
2. **repo_prepare**: Configure local repo file
3. **repo_nginx**: Start Nginx if needed


## See Also

- [`infra`](../infra): Infrastructure deployment
- [`cache`](../cache): Create offline package cache
- [Offline Install](https://pigsty.io/docs/setup/offline): Offline installation guide
