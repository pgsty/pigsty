# Role: vibe

> Deploy Development Tools (Code Server, JupyterLab, Claude Code, optional Codex)

| **Module**        | [VIBE](https://pigsty.io/docs/vibe) |
|-------------------|-------------------------------------|
| **Docs**          | https://pigsty.io/docs/vibe/        |
| **Related Roles** | `node`, `juice`                     |


## Overview

The `vibe` role deploys an integrated development environment:

- **Code Server**: VS Code in browser
- **JupyterLab**: Interactive computing notebooks
- **Claude Code**: default AI coding assistant with observability
- **Codex**: optional CLI package install only
- **Node.js**: Standalone JavaScript runtime with optional npm packages


## Quick Start

Use `conf/vibe.yml` for a complete AI coding sandbox:

```bash
./configure -c vibe
./deploy.yml
./juice.yml     # JuiceFS on PostgreSQL, mount on /fs
./vibe.yml      # Code Server, JupyterLab, Claude Code
```


## Playbooks

| Playbook   | Description              |
|------------|--------------------------|
| `vibe.yml` | Deploy development tools |


## Tags

```text
vibe
├── vibe_dir          # Create workspace, render AGENTS.md
├── code              # VS Code Server
│   ├── code_install
│   ├── code_dir
│   ├── code_config
│   └── code_launch
├── jupyter           # JupyterLab
│   ├── jupyter_install
│   ├── jupyter_dir
│   ├── jupyter_config
│   └── jupyter_launch
├── nodejs            # Node.js runtime
│   ├── nodejs_install
│   ├── nodejs_config
│   └── nodejs_pkg
├── claude            # Claude Code CLI
│   ├── claude_install
│   └── claude_config
└── codex             # Codex CLI
    └── codex_install
```


## Variables

### Workspace

| Variable    | Default | Description                |
|-------------|---------|----------------------------|
| `vibe_data` | `/fs`   | Shared workspace directory |

### Code Server

| Variable        | Default       | Description                          |
|-----------------|---------------|--------------------------------------|
| `code_enabled`  | `true`        | Enable code-server                   |
| `code_port`     | `8443`        | Listen port                          |
| `code_data`     | `/data/code`  | Data directory                       |
| `code_password` | `Vibe.Coding` | Access password                      |
| `code_gallery`  | `openvsx`     | Extension gallery: openvsx/microsoft |

### JupyterLab

| Variable           | Default         | Description            |
|--------------------|-----------------|------------------------|
| `jupyter_enabled`  | `false`         | Enable JupyterLab      |
| `jupyter_port`     | `8888`          | Listen port            |
| `jupyter_data`     | `/data/jupyter` | Data directory         |
| `jupyter_password` | `Vibe.Coding`   | Access token           |
| `jupyter_venv`     | `/data/venv`    | Python venv path       |

### Claude Code

| Variable         | Default  | Description                                 |
|------------------|----------|---------------------------------------------|
| `claude_enabled` | `true`   | Install and configure Claude Code           |
| `claude_package` | `claude` | Native infra package used to install Claude |
| `claude_env`     | `{}`     | Extra env vars merged with defaults         |

Claude Code is pre-configured with OpenTelemetry, sending metrics and logs to VictoriaMetrics/VictoriaLogs at `admin_ip`. Prompt content is not collected by default; opt in through `claude_env` only when appropriate. The role preserves other keys in the user's `~/.claude/settings.json`.

### Codex

| Variable        | Default | Description                     |
|-----------------|---------|---------------------------------|
| `codex_enabled` | `true`  | Install the Codex CLI package   |

Codex has no managed config file and no VIBE observability integration. When enabled, the role installs the native `codex` infra package.

### Node.js

| Variable          | Default | Description                                      |
|-------------------|---------|--------------------------------------------------|
| `nodejs_enabled`  | `true`  | Enable standalone Node.js installation task      |
| `nodejs_registry` | `''`    | npm registry URL, auto china mirror if empty     |
| `npm_packages`    | `[]`    | Extra global npm packages to install             |

Node.js is independent of Claude and Codex. Enabling either agent does not install Node.js.

When `nodejs_registry` is empty and `region=china`, npm is automatically configured to use `https://registry.npmmirror.com`.

`npm_packages` is only for extra global npm packages installed with the Node.js runtime:

```yaml
npm_packages:
  - 'happy-coder'
  - typescript
  - pnpm
```


## Usage

VIBE packages (`code-server`, `claude`, `codex`, `nodejs`) are served from the `pigsty-infra` repository (`infra` in `node_repo_modules`, included in `conf/vibe.yml` and `conf/meta.yml`).

```bash
./vibe.yml -l <host>                                    # Full deployment
./vibe.yml -l <host> -t code                            # Code Server only
./vibe.yml -l <host> -t jupyter -e jupyter_enabled=true # JupyterLab only (disabled by default)
./vibe.yml -l <host> -t claude                          # Install/configure Claude Code
./vibe.yml -l <host> -t codex                           # Install Codex package only
./vibe.yml -l <host> -t nodejs                          # Node.js only
```

Disable components:

```bash
./vibe.yml -l <host> -e code_enabled=false
./vibe.yml -l <host> -e jupyter_enabled=false
./vibe.yml -l <host> -e claude_enabled=false
./vibe.yml -l <host> -e codex_enabled=false
./vibe.yml -l <host> -e nodejs_enabled=false
```


## Access

| Service     | Via Nginx                 | Direct                           |
|-------------|---------------------------|----------------------------------|
| Code Server | `https://<host>/code/`    | `http://127.0.0.1:8443/` (local) |
| JupyterLab  | `https://<host>/jupyter/` | `http://<host>:8888/jupyter/`    |


## Authentication

Codex is intentionally package-only in VIBE. Custom Codex providers, config rendering, and telemetry are not exposed as VIBE variables.

For **Claude Code**, alternative models use Anthropic-compatible endpoints via env vars:

```yaml
claude_enabled: true
claude_env:
  ANTHROPIC_BASE_URL: https://api.z.ai/api/anthropic
  ANTHROPIC_AUTH_TOKEN: <your_zai_api_key>
  API_TIMEOUT_MS: "3000000"
```


## See Also

- `node`: Node provisioning
- `infra`: Nginx reverse proxy
- `juice`: JuiceFS distributed filesystem
- `conf/vibe.yml`: Complete sandbox template
