# Hermes Agent on Pigsty VM

本文记录一次真实执行过的 bring-up，目标非常单纯：

- 在一台已经部署 Pigsty 的 `Ubuntu 24.04` 虚拟机上把 [Hermes Agent](https://github.com/NousResearch/hermes-agent) 跑起来
- 不在这台小虚机上部署本地 Ollama / vLLM
- 直接使用外部 `z.ai / GLM` API 作为推理后端
- 把所有关键操作沉淀为可复现文档，便于后续扩展成 Pigsty Enormous 方案

本次实际目标机是 `ssh meta` 对应的虚机，最终验收结果是：

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

本次实际观测结果：

- OS: `Ubuntu 24.04.3 LTS`
- Arch: `arm64`
- CPU: `2`
- RAM: `3.7 GiB`
- Root disk: `30G`

为什么这很重要：

- 这台虚机资源很小，不适合再拉本地大模型
- Ubuntu 24.04 自带 `python3.12`
- 直接用系统 Python + `uv` 安装 Hermes，比在这台机子上再折腾本地推理框架更合适


## 2. 固定上游版本

为了复现，**不要**直接跟浮动的 `main`。

本次实际固定的上游版本：

- Repo: `https://github.com/NousResearch/hermes-agent`
- Commit: `af9caec44fdab7a1b883dede16fe1ce8c2d60fb9`
- Commit Time: `2026-04-11T10:29:09Z`

对应源码 tarball：

```text
https://codeload.github.com/NousResearch/hermes-agent/tar.gz/af9caec44fdab7a1b883dede16fe1ce8c2d60fb9
```


## 3. 网络与代理

这台 VM 如果需要通过宿主机代理访问外网，优先使用：

```text
http://10.0.2.2:8118
```

这是本次在 `meta` 上实际可用的宿主机代理入口。

如果 GitHub 下载不通，可以在命令前加：

```bash
export PROXY=http://10.0.2.2:8118
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
ssh meta 'python3 --version; uv --version; git --version; curl --version | head -n 1'
```

本次环境里这些命令都已经存在，因此不需要额外安装 Python / uv。


### 4.2 下载固定版本源码

不需要代理时：

```bash
ssh meta '
set -euo pipefail
wget -O /tmp/hermes-agent.tar.gz \
  https://codeload.github.com/NousResearch/hermes-agent/tar.gz/af9caec44fdab7a1b883dede16fe1ce8c2d60fb9
ls -lh /tmp/hermes-agent.tar.gz
'
```

需要代理时：

```bash
ssh meta '
set -euo pipefail
export PROXY=http://10.0.2.2:8118
export HTTP_PROXY=$PROXY HTTPS_PROXY=$PROXY ALL_PROXY=$PROXY
wget -O /tmp/hermes-agent.tar.gz \
  https://codeload.github.com/NousResearch/hermes-agent/tar.gz/af9caec44fdab7a1b883dede16fe1ce8c2d60fb9
ls -lh /tmp/hermes-agent.tar.gz
'
```


### 4.3 解压并安装到 `~/.hermes/hermes-agent`

```bash
ssh meta '
set -euo pipefail
INSTALL_DIR="$HOME/.hermes/hermes-agent"
mkdir -p "$HOME/.hermes" "$HOME/.local/bin"

SRC_DIR="$(tar -tzf /tmp/hermes-agent.tar.gz | head -1 | cut -d/ -f1)"
rm -rf "$INSTALL_DIR" "/tmp/$SRC_DIR"
mkdir -p "$INSTALL_DIR"

tar -xzf /tmp/hermes-agent.tar.gz -C /tmp
shopt -s dotglob
mv "/tmp/$SRC_DIR"/* "$INSTALL_DIR"/
rmdir "/tmp/$SRC_DIR"

cd "$INSTALL_DIR"
uv venv venv --python /usr/bin/python3
. venv/bin/activate
uv pip install -e ".[cli,pty,mcp,cron]"

ln -sf "$INSTALL_DIR/venv/bin/hermes" "$HOME/.local/bin/hermes"
ln -sf "$INSTALL_DIR/venv/bin/hermes-agent" "$HOME/.local/bin/hermes-agent"

"$HOME/.local/bin/hermes" --help | sed -n "1,80p"
'
```

说明：

- `.[cli,pty,mcp,cron]` 足够完成当前阶段 bring-up
- 这比在小 VM 上装 `.[all]` 更保守
- 这里直接使用系统 `python3.12`


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
cd ~/.hermes/hermes-agent
GLM_API_KEY="<YOUR_GLM_API_KEY>" ./venv/bin/python - <<'"'"'PY'"'"'
import json, os
from hermes_cli.auth import detect_zai_endpoint
print(json.dumps(detect_zai_endpoint(os.environ["GLM_API_KEY"]), ensure_ascii=False))
PY
'
```

本次实际探测结果：

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

这一步不需要整份默认配置，下面这份最小配置已经做过真实验证，可以直接用：

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

```bash
ssh meta '
set -euo pipefail
source ~/.profile
~/.local/bin/hermes doctor
'
```

本次实际关键结果是：

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

本次实际返回：

```text
hermes-final-ok provider=zai model=glm-5
```

只要能拿到这类返回，就说明这条链路已经跑通：

- Hermes CLI 正常
- 配置文件生效
- `.env` 生效
- 远端 GLM API 可达
- 终端后端可用


## 7. 最小配置已验证

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

本次实际返回：

```text
minimal-config-ok
```

这证明文中的最小配置不是理论写法，而是实际跑通过的。


## 8. 清理本地试验组件

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


## 9. 当前最终状态

在 `meta` 上，本次最终状态如下：

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
