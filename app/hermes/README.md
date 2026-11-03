# Hermes Agent on Pigsty VM

本文提供固定稳定版 `0.21.5`（tag `v2026.9.24`）的安装步骤，并保留早期 `0.8.0` 的真实 bring-up 记录：

- 在一台已经部署 Pigsty 的 `Ubuntu 24.04` 虚拟机上把 [Hermes Agent](https://github.com/NousResearch/hermes-agent) 跑起来
- 不在这台小虚机上部署本地 Ollama / vLLM
- 直接使用外部 `z.ai / GLM` API 作为推理后端
- 把所有关键操作沉淀为可复现文档，便于后续扩展成 Pigsty Enormous 方案

历史 `0.8.0` 验收使用 `ssh meta` 对应的虚机，结果如下；这些对话结果不代表新版已经调用过付费 API：

- Hermes 安装路径：`/home/vagrant/.hermes/hermes-agent`
- Hermes 版本：`v0.8.0 (2026.4.8)`
- Provider：`zai`
- Model：`glm-5`
- `hermes chat -q ...` 已经成功返回


## 1. 目标环境

先确认目标机基础信息：

```bash
ssh meta 'hostnamectl; echo; uname -a; echo; nproc; free -h; df -h /'
```

历史 `meta` 实际观测结果：

- OS: `Ubuntu 24.04.3 LTS`
- Arch: `arm64`
- CPU: `2`
- RAM: `3.7 GiB`
- Root disk: `30G`

为什么这很重要：

- 这台虚机资源很小，不适合再拉本地大模型
- Ubuntu 24.04 自带 `python3.12`
- 直接用系统 Python + 独立虚拟环境 安装 Hermes，比在这台机子上再折腾本地推理框架更合适


## 2. 固定上游版本

为了复现，**不要**直接跟浮动的 `main`。

当前安装步骤固定上游稳定版：

- Repo: `https://github.com/NousResearch/hermes-agent`
- Tag: [`v2026.9.24`](https://github.com/NousResearch/hermes-agent/releases/tag/v2026.9.24)
- Package: `0.21.5`
- Commit: `f97608f178d1ffeca59860195ab7da295f7c8e5f`
- Commit Time: `2026-09-24T10:08:47Z`
- Tarball SHA-256: `babbdb9706ad1c96708d75914afb45d809cd4b73dec1ceae233a6814f5ed97e3`

历史 `0.8.0` 使用 commit `af9caec44fdab7a1b883dede16fe1ce8c2d60fb9`；新安装使用以下源码 tarball：

```text
https://codeload.github.com/NousResearch/hermes-agent/tar.gz/f97608f178d1ffeca59860195ab7da295f7c8e5f
```


## 3. 网络与代理

这台 VM 下载源码或依赖需要代理时，按需使用宿主机的 Xray；先确认该入口在容器或 VM 内可达：

```text
http://10.0.2.2:8888
```

2026-10-01 起通用下载统一使用 8888；本文原始安装时在 `meta` 验证过的是 8118。m1/m5 的 8118 仅用于 AI 派活或模型调用。

如果 GitHub 下载不通，可以在命令前加：

```bash
export PROXY=http://10.0.2.2:8888
export HTTP_PROXY=$PROXY
export HTTPS_PROXY=$PROXY
export ALL_PROXY=$PROXY
```

本次实际情况：

- 下载 Hermes 源码时，代理能力可用
- 最终运行 `z.ai / GLM` API 时，**不需要**依赖这个代理


## 4. 安装 Hermes

### 4.1 检查基础命令

```bash
ssh meta 'python3.12 --version; git --version; curl --version | head -n 1'
```

需要 Python 3.12 和 `python3.12-venv`。Ubuntu 24.04 的系统 Python 满足当前 `>=3.11,<3.14` 的要求；使用独立虚拟环境安装。


### 4.2 下载固定版本源码

不需要代理时：

```bash
ssh meta '
set -euo pipefail
wget -O /tmp/hermes-agent.tar.gz \
  https://codeload.github.com/NousResearch/hermes-agent/tar.gz/f97608f178d1ffeca59860195ab7da295f7c8e5f
ls -lh /tmp/hermes-agent.tar.gz
'
```

需要代理时：

```bash
ssh meta '
set -euo pipefail
export PROXY=http://10.0.2.2:8888
export HTTP_PROXY=$PROXY HTTPS_PROXY=$PROXY ALL_PROXY=$PROXY
export http_proxy=$PROXY https_proxy=$PROXY all_proxy=$PROXY
wget -O /tmp/hermes-agent.tar.gz \
  https://codeload.github.com/NousResearch/hermes-agent/tar.gz/f97608f178d1ffeca59860195ab7da295f7c8e5f
ls -lh /tmp/hermes-agent.tar.gz
'
```


### 4.3 校验并安装到独立版本目录

保留现有安装和配置，先在新的版本目录验收：

```bash
ssh meta '
set -euo pipefail
printf "%s  %s\n" \
  babbdb9706ad1c96708d75914afb45d809cd4b73dec1ceae233a6814f5ed97e3 \
  /tmp/hermes-agent.tar.gz | sha256sum -c -
INSTALL_DIR="$HOME/.hermes/hermes-agent-v2026.9.24"
test ! -e "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
tar -xzf /tmp/hermes-agent.tar.gz -C "$INSTALL_DIR" --strip-components=1
cd "$INSTALL_DIR"
python3.12 -m venv venv
. venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -e ".[pty,mcp,cron]"
python -m pip check
./venv/bin/hermes --help
./venv/bin/hermes --version
'
```

以该 tag 的 [`pyproject.toml`](https://github.com/NousResearch/hermes-agent/blob/v2026.9.24/pyproject.toml) 为准：

- CLI 依赖已经属于核心包，删除旧的 `cli` extra。
- `pty` 和 `cron` extra 为空，保留名称表示选用这些功能；MCP extra 安装 MCP 2、httpx2 和 Starlette。
- 无需安装 `.[all]`；当前路线继续使用 Python 3.12 与外部 Z.AI / GLM。

上游禁止普通 wheel/sdist 构建，使用上述 editable 源码安装。

先用新二进制和独立 `HERMES_HOME` 运行 `--version` / `doctor`。需要切换正式入口时，保留旧目录再更新符号链接：

```bash
ssh meta '
set -euo pipefail
mkdir -p "$HOME/.local/bin"
ln -sfn "$HOME/.hermes/hermes-agent-v2026.9.24/venv/bin/hermes" "$HOME/.local/bin/hermes"
ln -sfn "$HOME/.hermes/hermes-agent-v2026.9.24/venv/bin/hermes-agent" "$HOME/.local/bin/hermes-agent"
'
```


## 5. 配置远端 GLM API

### 5.1 准备 API Key

Hermes 对 `z.ai / GLM` 的环境变量名是：

- `GLM_API_KEY`
- `ZAI_API_KEY`
- `Z_AI_API_KEY`

本次实际使用的是 `GLM_API_KEY`。

不要把真实 key 提交进仓库。下面的文档统一用占位符表示：

```text
<YOUR_GLM_API_KEY>
```


### 5.2 可选：让 Hermes 自动探测该 key 对应的 endpoint

如果你不确定这把 key 该走全球站还是国内站，可以直接调用 Hermes 自己的探测逻辑：

```bash
ssh meta '
set -euo pipefail
cd ~/.hermes/hermes-agent-v2026.9.24
GLM_API_KEY="<YOUR_GLM_API_KEY>" ./venv/bin/python - <<'"'"'PY'"'"'
import json, os
from hermes_cli.auth import detect_zai_endpoint
print(json.dumps(detect_zai_endpoint(os.environ["GLM_API_KEY"]), ensure_ascii=False))
PY
'
```

历史 `0.8.0` 实际探测结果：

```json
{"id":"global","base_url":"https://api.z.ai/api/paas/v4","model":"glm-5","label":"Global"}
```

因此本次最终配置使用：

```text
GLM_BASE_URL=https://api.z.ai/api/paas/v4
model.default=glm-5
```

如果你的 key 是国内入口，可以改成：

```text
https://open.bigmodel.cn/api/paas/v4
```


### 5.3 写入 `~/.hermes/.env`

如果目标机上已经有旧配置，先备份：

```bash
ssh meta '
set -euo pipefail
TS=$(date +%Y%m%d-%H%M%S)
cp ~/.hermes/.env ~/.hermes/.env.bak-$TS 2>/dev/null || true
cp ~/.hermes/config.yaml ~/.hermes/config.yaml.bak-$TS 2>/dev/null || true
'
```

然后写入新的 `.env`：

```bash
ssh meta '
set -euo pipefail
mkdir -p ~/.hermes
cat > ~/.hermes/.env <<'"'"'EOF'"'"'
TERMINAL_ENV=local
TERMINAL_CWD=/home/vagrant
GLM_API_KEY=<YOUR_GLM_API_KEY>
GLM_BASE_URL=https://api.z.ai/api/paas/v4
EOF
chmod 600 ~/.hermes/.env
'
```


### 5.4 写入最小可用 `~/.hermes/config.yaml`

下面这份最小配置在历史 `0.8.0` 环境通过真实 GLM 验证。新版安装后先运行 `doctor`，再用已授权的 API key 验证对应 provider：

```bash
ssh meta '
set -euo pipefail
mkdir -p ~/.hermes
cat > ~/.hermes/config.yaml <<'"'"'EOF'"'"'
model:
  provider: zai
  default: glm-5
providers: {}
toolsets:
  - hermes-cli
terminal:
  backend: local
  cwd: /home/vagrant
display:
  streaming: false
EOF
'
```

说明：

- `provider: zai` 明确告诉 Hermes 使用 GLM provider
- `default: glm-5` 对应本次实际可用的模型
- `terminal.backend: local` 表示命令在这台 VM 本机执行
- `display.streaming: false` 让 CLI 输出更稳定一些，便于排障


## 6. 验证

### 6.1 运行 `hermes doctor`

正式运行前检查目标 VM 中 Python 链接的 SQLite 版本及状态数据库的 journal mode。
已有 WAL 数据库不会由 Hermes 自动切换模式；WAL 并发写入或 checkpoint 应使用
[修复了 WAL-reset 缺陷的 SQLite](https://sqlite.org/wal.html#walresetbug)
（`3.51.3+`、`3.50.7` 或 `3.44.6`）。保留本文固定源码，不要直接运行 `hermes update` 改变版本。

```bash
ssh meta '
set -euo pipefail
source ~/.profile
~/.local/bin/hermes doctor
'
```

历史 `0.8.0` 使用真实 API key 时的关键结果是：

```text
Checking Z.AI / GLM API...
✓ Z.AI / GLM
```


### 6.2 运行最小对话验收

```bash
ssh meta '
set -euo pipefail
source ~/.profile
~/.local/bin/hermes chat -q "请用一行回复：hermes-final-ok provider=zai model=glm-5"
'
```

历史 `0.8.0` 实际返回：

```text
hermes-final-ok provider=zai model=glm-5
```

只要能拿到这类返回，就说明这条链路已经跑通：

- Hermes CLI 正常
- 配置文件生效
- `.env` 生效
- 远端 GLM API 可达
- 终端后端可用


## 7. 历史最小配置验证

为了保证文档本身可复现，本次还单独用一个临时目录做过最小配置验证：

```bash
ssh meta '
set -euo pipefail
TMP=/tmp/hermes-minimal-test
rm -rf "$TMP"
mkdir -p "$TMP"

cat > "$TMP/config.yaml" <<'"'"'EOF'"'"'
model:
  provider: zai
  default: glm-5
providers: {}
toolsets:
  - hermes-cli
terminal:
  backend: local
  cwd: /home/vagrant
display:
  streaming: false
EOF

cat > "$TMP/.env" <<'"'"'EOF'"'"'
TERMINAL_ENV=local
TERMINAL_CWD=/home/vagrant
GLM_API_KEY=<YOUR_GLM_API_KEY>
GLM_BASE_URL=https://api.z.ai/api/paas/v4
EOF

source ~/.profile
HERMES_HOME="$TMP" ~/.local/bin/hermes doctor
HERMES_HOME="$TMP" ~/.local/bin/hermes chat -q "只回复 minimal-config-ok"
'
```

历史 `0.8.0` 实际返回：

```text
minimal-config-ok
```

这证明文中的最小配置不是理论写法，而是实际跑通过的。


## 8. 历史试验组件清理记录

本次最终交付**不使用本地 Ollama，也不使用本地 smoke endpoint**。

如果你之前做过类似试验，可以按下面方式清理：

```bash
ssh meta '
set -euo pipefail
sudo systemctl disable --now hermes-smoke-llm.service ollama.service >/dev/null 2>&1 || true
sudo rm -f /etc/systemd/system/hermes-smoke-llm.service /etc/systemd/system/ollama.service
rm -f ~/.hermes/mock_openai_server.py ~/.hermes/mock_openai_requests.log
sudo rm -f /usr/local/bin/ollama
sudo rm -rf /usr/local/lib/ollama /usr/share/ollama
sudo systemctl daemon-reload
'
```

本次实际执行后，相关 service/binary/path 都已经被清掉。


## 9. 历史 0.8.0 最终状态

早期 `0.8.0` 验收结束时，`meta` 的状态如下：

- Hermes 安装在 `~/.hermes/hermes-agent`
- 实际运行 provider 是 `zai`
- 实际运行 model 是 `glm-5`
- 本地 smoke endpoint 已移除
- 本地 Ollama 已移除
- 当前推荐路线是：`Pigsty VM + Hermes + 外部 GLM API`


## 10. 后续扩展方向

完成“先跑起来”之后，下一阶段可以继续做这几件事：

1. 把 `.env` 管理纳入 Pigsty 标准化配置分发，而不是手工写入
2. 把 `~/.hermes` 目录布局收敛成可 Ansible 化的交付物
3. 评估是否要把 `Hermes + Hindsight + Pigsty PostgreSQL` 组合成一个标准 AI agent node
4. 再决定是否需要引入本地推理层；如果要引入，应当按 Pigsty Enormous 的资源与缓存策略统一设计，而不是在 2C4G 小虚机上临时试


## 11. 参考

- [Hermes Agent Repository](https://github.com/NousResearch/hermes-agent)
- [Hermes Provider Docs](https://hermes-agent.nousresearch.com/docs/integrations/providers/)
- [Hermes Configuration Docs](https://hermes-agent.nousresearch.com/docs/user-guide/configuration/)
