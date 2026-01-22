# JUPYTER

Deploy [Jupyter Lab](https://jupyter.org/) - Interactive computing environment.


## Overview

The `jupyter` role deploys Jupyter Lab on Pigsty managed nodes, providing a web-based interactive development environment accessible through nginx reverse proxy.

```
┌─────────────────────────────────────────────────────────────┐
│                    Nginx (443/80)                           │
│              https://i.pigsty/jupyter/                      │
│              https://jupyter.pigsty (optional)              │
└──────────────────────────┬──────────────────────────────────┘
                           │ proxy_pass
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                 Jupyter Lab (127.0.0.1:8888)                │
│                                                             │
│  User: {{ node_user }}                                      │
│  WorkDir: {{ jupyter_home }}  (e.g., /fs/jupyter)           │
│  DataDir: {{ jupyter_data }}  (e.g., /data/jupyter)         │
│  Venv: {{ jupyter_venv }}     (e.g., /data/venv)            │
└─────────────────────────────────────────────────────────────┘
```

**Prerequisites**: Jupyter must be installed in the venv before running this role:

```bash
uv pip install jupyterlab ipykernel --python /data/venv/bin/python
```


## Variables

```yaml
jupyter_enabled: false            # enable jupyter on this node?
jupyter_port: 8888                # jupyter listen port
jupyter_home: /fs/jupyter         # jupyter working directory (notebook root)
jupyter_data: /data/jupyter       # jupyter data directory
jupyter_password: 'Jupyter.Lab'   # jupyter login token
jupyter_venv: /data/venv          # python venv path where jupyter is installed
```

| Variable           | Default         | Description                      |
|--------------------|-----------------|----------------------------------|
| `jupyter_enabled`  | `false`         | Enable jupyter on this node      |
| `jupyter_port`     | `8888`          | Listen port (localhost only)     |
| `jupyter_home`     | `/fs/jupyter`   | Working directory for notebooks  |
| `jupyter_data`     | `/data/jupyter` | Data directory (config, kernels) |
| `jupyter_password` | `Jupyter.Lab`   | Login token                      |
| `jupyter_venv`     | `/data/venv`    | Python venv path                 |


## Directory Structure

```
/fs/jupyter/                      # jupyter_home - notebook directory
├── *.ipynb                       # notebook files
└── ...
/data/jupyter/                    # jupyter_data - data directory
├── jupyter_config.py             # jupyter configuration
├── kernels/                      # installed kernels
└── ...
/data/venv/                       # jupyter_venv - python venv
├── bin/jupyter                   # jupyter executable
└── ...
```


## Usage

### Deploy Jupyter

```bash
# Enable in pigsty.yml
jupyter_enabled: true

# Deploy to specific host
./jupyter.yml -l <host>

# One-liner deployment
./jupyter.yml -l infra -e jupyter_enabled=true
```

### Access

- **Sub-path**: `https://i.pigsty/jupyter/`
- **Sub-domain** (optional): `https://jupyter.pigsty`

Login with the token configured in `jupyter_password`.


## Tasks

| Tag              | Description                 |
|------------------|-----------------------------|
| `jupyter`        | Full jupyter deployment     |
| `jupyter_dir`    | Create directories          |
| `jupyter_config` | Render configuration files  |
| `jupyter_launch` | Start systemd service       |


## Files

| Template            | Destination                            | Description           |
|---------------------|----------------------------------------|-----------------------|
| `jupyter_config.py` | `{{ jupyter_data }}/jupyter_config.py` | Jupyter config        |
| `jupyter.svc`       | `/etc/systemd/system/jupyter.service`  | systemd unit          |
| `jupyter.env`       | `/etc/default/jupyter`                 | environment variables |


## Nginx Integration

The `/jupyter/` location is configured in nginx `home.conf`:

```nginx
location /jupyter/ {
    proxy_pass http://127.0.0.1:8888/;  # strip /jupyter/ prefix
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_read_timeout 86400s;
    proxy_send_timeout 86400s;
}
```

Note: nginx strips the `/jupyter/` prefix, while JupyterLab uses `base_url='/jupyter/'` to generate correct links.

For sub-domain access, add to `infra_portal`:

```yaml
infra_portal:
  jupyter:
    domain: jupyter.pigsty
    endpoint: "10.10.10.10:8888"
    websocket: true
```


## Example Configuration

```yaml
all:
  vars:
    jupyter_enabled: true
    jupyter_home: /home/dba/notebooks
    jupyter_password: 'MySecureToken'
    jupyter_venv: /data/venv
```
