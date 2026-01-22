# CODE

Deploy [code-server](https://github.com/coder/code-server) - VS Code in the browser.


## Overview

The `code` role deploys code-server on Pigsty managed nodes, providing a web-based VS Code IDE accessible through nginx reverse proxy.

```
┌─────────────────────────────────────────────────────────────┐
│                    Nginx (443/80)                           │
│              https://i.pigsty/code/                         │
│              https://code.pigsty (optional)                 │
└──────────────────────────┬──────────────────────────────────┘
                           │ proxy_pass
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                 code-server (127.0.0.1:8443)                │
│                                                             │
│  User: {{ node_user }}                                      │
│  WorkDir: {{ code_home }}     (e.g., /fs/code)              │
│  DataDir: {{ code_data }}     (e.g., /data/code)            │
└─────────────────────────────────────────────────────────────┘
```


## Variables

```yaml
code_enabled: false               # enable code-server on this node?
code_port: 8443                   # code-server listen port
code_home: /fs/code               # code-server working directory (open folder)
code_data: /data/code             # code-server user data directory
code_password: 'Code.Server'      # code-server password
code_extensions: []               # extensions to be installed
```

| Variable | Default | Description |
|----------|---------|-------------|
| `code_enabled` | `false` | Enable code-server on this node |
| `code_port` | `8443` | Listen port (localhost only) |
| `code_home` | `/fs/code` | Working directory opened in VS Code |
| `code_data` | `/data/code` | User data directory (extensions, settings) |
| `code_password` | `Code.Server` | Login password |
| `code_extensions` | `[]` | List of extensions to install |


## Directory Structure

```
/fs/code/                         # code_home - working directory
/data/code/                       # code_data - user data directory
├── code-server/
│   └── config.yaml               # code-server configuration
├── extensions/                   # installed extensions
├── User/                         # user settings
└── ...
```


## Usage

### Deploy code-server

```bash
# Enable in pigsty.yml
code_enabled: true

# Deploy to specific host
./code.yml -l <host>

# One-liner deployment
./code.yml -l infra -e code_enabled=true
```

### Access

- **Sub-path**: `https://i.pigsty/code/`
- **Sub-domain** (optional): `https://code.pigsty`

Login with the password configured in `code_password`.

### Install Extensions

```yaml
code_extensions:
  - ms-python.python
  - redhat.vscode-yaml
  - golang.go
```

Or install manually after deployment:

```bash
./code.yml -l <host> -t code_extensions -e '{"code_extensions":["ms-python.python"]}'
```


## Tasks

| Tag | Description |
|-----|-------------|
| `code` | Full code-server deployment |
| `code_install` | Install code-server package |
| `code_dir` | Create directories |
| `code_config` | Render configuration files |
| `code_launch` | Start systemd service |
| `code_extensions` | Install VS Code extensions |


## Files

| Template | Destination | Description |
|----------|-------------|-------------|
| `code.yml` | `{{ code_data }}/code-server/config.yaml` | code-server config |
| `code.svc` | `/etc/systemd/system/code-server.service` | systemd unit |
| `code.env` | `/etc/default/code` | environment variables |


## Nginx Integration

The `/code/` location is configured in nginx `home.conf`:

```nginx
location /code/ {
    proxy_pass http://127.0.0.1:8443/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_read_timeout 86400s;
    proxy_send_timeout 86400s;
    proxy_redirect / /code/;
}
```

For sub-domain access, add to `infra_portal`:

```yaml
infra_portal:
  code:
    domain: code.pigsty
    endpoint: "10.10.10.10:8443"
    websocket: true
```


## China Region

In China region (`region: china`), the extension marketplace is automatically configured to use Tsinghua mirror:

```bash
EXTENSIONS_GALLERY={"serviceUrl":"https://open-vsx.tuna.tsinghua.edu.cn/vscode/gallery","itemUrl":"https://open-vsx.tuna.tsinghua.edu.cn/vscode/item"}
```


## Example Configuration

```yaml
all:
  vars:
    code_enabled: true
    code_home: /home/dba/pigsty
    code_password: 'MySecurePassword'
    code_extensions:
      - ms-python.python
      - redhat.vscode-yaml
      - hashicorp.terraform
```
