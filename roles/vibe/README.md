# Role: vibe

> Deploy Development Tools (Code Server, JupyterLab, Claude Code)

| **Module**        | [VIBE](https://pigsty.io/docs/vibe)    |
|-------------------|----------------------------------------|
| **Docs**          | https://pigsty.io/docs/vibe/           |
| **Related Roles** | [`node`](../node), [`juice`](../juice) |


## Overview

The `vibe` role deploys an integrated development environment:

- **Code Server**: VS Code in browser
- **JupyterLab**: Interactive computing notebooks
- **Claude Code**: AI coding assistant with observability
- **Node.js**: JavaScript runtime with npm


## Quick Start

Use [`conf/vibe.yml`](../../conf/vibe.yml) for a complete AI coding sandbox:

```bash
./configure -c vibe
./deploy.yml
./juice.yml     # JuiceFS on PostgreSQL, mount on /fs
./vibe.yml      # Code Server, JupyterLab, Claude Code
```


## Playbooks

| Playbook                     | Description              |
|------------------------------|--------------------------|
| [`vibe.yml`](../../vibe.yml) | Deploy development tools |


## Tags

```
vibe
├── vibe_dir          # Create workspace, render CLAUDE.md
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
├── nodejs            # Node.js Runtime (claude-code installed here via npm)
│   ├── nodejs_install
│   ├── nodejs_config
│   └── nodejs_pkg
└── claude            # Claude Code CLI Config
    └── claude_config
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

| Variable         | Default | Description                         |
|------------------|---------|-------------------------------------|
| `claude_enabled` | `true`  | Enable Claude Code                  |
| `claude_env`     | `{}`    | Extra env vars merged with defaults |

Claude Code is pre-configured with OpenTelemetry, sending metrics and logs to VictoriaMetrics/VictoriaLogs for observability.

### Node.js

| Variable          | Default | Description                                      |
|-------------------|---------|--------------------------------------------------|
| `nodejs_enabled`  | `true`  | Enable Node.js installation                      |
| `nodejs_registry` | `''`    | npm registry URL, auto china mirror if empty     |
| `npm_packages`    | `['@anthropic-ai/claude-code', 'happy-coder']` | List of global npm packages to install |

When `nodejs_registry` is empty and `region=china`, npm is automatically configured to use `https://registry.npmmirror.com`.

Claude Code is installed by default via `npm_packages`. You can add more packages as needed:

```yaml
npm_packages:
  - '@anthropic-ai/claude-code'
  - 'happy-coder'
  - typescript
  - pnpm
```


## Usage

```bash
./vibe.yml -l <host>              # Full deployment
./vibe.yml -l <host> -t code      # Code Server only
./vibe.yml -l <host> -t jupyter   # JupyterLab only
./vibe.yml -l <host> -t claude    # Claude Code only
./vibe.yml -l <host> -t nodejs    # Node.js only
```

Disable components:

```bash
./vibe.yml -l <host> -e code_enabled=false
./vibe.yml -l <host> -e jupyter_enabled=false
./vibe.yml -l <host> -e claude_enabled=false
./vibe.yml -l <host> -e nodejs_enabled=false
```


## Access

| Service     | Via Nginx                  | Direct                |
|-------------|----------------------------|-----------------------|
| Code Server | `https://<host>/code/`     | `http://<host>:8443/` |
| JupyterLab  | `https://<host>/jupyter/`  | `http://<host>:8888/` |


## Using Alternative Models

To use other models with Claude Code, configure `claude_env`, take GLM as example:

```yaml
claude_env:
  ANTHROPIC_BASE_URL: https://open.bigmodel.cn/api/anthropic
  ANTHROPIC_API_URL: https://open.bigmodel.cn/api/anthropic
  ANTHROPIC_AUTH_TOKEN: <your_api_key>
  ANTHROPIC_MODEL: glm-4.7
  ANTHROPIC_SMALL_FAST_MODEL: glm-4.5-air
```


## See Also

- [`node`](../node): Node provisioning
- [`infra`](../infra): Nginx reverse proxy
- [`juice`](../juice): JuiceFS distributed filesystem
- [`conf/vibe.yml`](../../conf/vibe.yml): Complete sandbox template
