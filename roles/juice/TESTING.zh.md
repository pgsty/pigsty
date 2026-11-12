# JUICE Beta 四节点发布前实测报告

日期：2026-11-11。操作手册位于 pigsty.cc 文档仓库的 `content/docs/juice/sop.md`，目前为草稿。

## 结论

在四台真实 Linux 沙箱上验证了 systemd、内核 FUSE、多个元数据/数据后端和实际 Victoria 抓取。Gemini 收敛后的多数修复有效，无需重新加入强制卸载、手写 mountinfo 解析或服务依赖编排。

在进入本轮时的未提交补丁基础上，补了三项必要调整：**停止结果核验、未命中 fsname 的主机提前跳过、准确声明并检查 Ansible 2.16 最低版本**。编写并执行了一个可重复的实机回归 playbook，脚本随测试资料归档；没有修改 `pigsty.yml`，也没有改动其他模块的既有未提交修改。

本轮明确的代码缺陷已修复。在本文描述的配置前提和测试范围内，没有剩余的已知发布阻塞项。指标端口被外部进程占用、后端离线时的缓存探测结果、VIBE 的就绪依赖仍有下述运行边界；不能据此宣称覆盖所有 Linux 发行版或具备生产级故障编排能力。

## 基线、范围与环境

- 仓库 HEAD：`f0fb2cb3f9fe7acfe5244ccdcb6642f5ca745d23`，包含执行开始时的全部 JUICE 未提交改动。
- 重点历史：`bc5c20b2`（2026-11-10，挂载校验、根目录权限后移、不自动重启、清理监控）；`d9194510`（2026-11-11，VIBE 属主已落库）；早期生命周期与 unit 拆分来自 `f69c1253`。
- 范围：`juice.yml`、`roles/juice/**`、`conf/vibe.yml`、VIBE 模板与 `roles/node_remove` 的 JuiceFS target 清理任务。
- 四节点：`10.10.10.10` / `.11` / `.12` / `.13`，Ubuntu 24.04.5，aarch64，systemd 255，util-linux 2.39.3，实际 `/dev/fuse`。`/data` 是 `/dev/vdb` 上的 XFS。
- JuiceFS：`1.4.2+2026-10-22.46af7af`，Pigsty 包 `1.4.2-1PGSTY`。
- 控制端：ansible-core 2.21.5；另使用 2.16.14 运行含特殊字符的完整实例配置；2.15.13 用于验证版本错误提示。
- 新建测试后端：PostgreSQL 16.15（端口 15432）、Redis 7.0.15（16379）、Silo `RELEASE.2026-10-26T00-00-00Z`（19000）、VictoriaMetrics 1.155.0（18428）。

沙箱的实际状态与 `pigsty.yml` 不同：开始时没有 PostgreSQL、JuiceFS 挂载；后三台有 OpenBao、HAProxy、Keepalived，整个测试期间未操作它们。测试使用新建的 `jr-*` 卷、合成数据和专用 inventory，没有读取业务数据或真实凭据。

运行原始资料保存在控制端仓库外：

```text
/Users/vonng/.cache/pigsty/juice-review-20261111/
  baseline/                 # 本轮开始时的 JUICE 源码
  baseline.diff             # 当时相对 HEAD 的未提交补丁
  final/tests/juice.yml      # 已执行的生命周期回归脚本，不纳入代码提交
  initial-worktree.json     # 原有未提交文件的 SHA-256
  inventories/              # 每组测试使用的完整配置
  lab.py, stage*.py          # 调度脚本
  outage.py, finalize.py     # 故障恢复、数据校验与收尾脚本
  cases.jsonl                # 每条命令、返回码、预期、耗时与日志位置
  logs/                      # 原始 stdout/stderr、实际 targets JSON
```

下文的证据编号对应 `logs/` 下同前缀文件。负向测试返回 `2` 是预期拒绝，不是漏测；初始脚本错误和被实测推翻的预期单独列在后文。

## 确认的问题与最小修复

### 1. 高：繁忙卸载失败仍报告清理成功并删除配置

**位置：** [`tasks/clean.yml`](tasks/clean.yml)。

**触发：** 单独的进程以挂载点为工作目录，执行 `state: absent` 清理。测试用独立 systemd `sleep` 服务持有工作目录，未使用任何业务进程。

**修复前证据：** `08-busy-clean-before.log` 为 `failed=0`，unit、环境文件和 target 都被删除；`09-busy-evidence-before.log` 同时记录 `fusermount: ... Device or resource busy`、`Control process exited ... status=1/FAILURE`、`Result=exit-code`。JuiceFS 等待约 30 秒后退出，本次内核挂载最终已消失；**没有据此声称实测留下死挂载**。问题是失败被当成成功，诊断配置也被提前删除。

**根因与归因：** `systemctl stop` 的返回码不能代替服务最终结果。早期实现忽略 stop 错误；Gemini 已收窄 `failed_when`，但仍只依赖 Ansible systemd 模块的成功返回，未覆盖这个真实 systemd 行为。

**修复：** 对本次停止的运行中服务读取 `systemctl show --property=Result --value`，结果不是 `success` 就在删除配置之前失败。不新增强制卸载，也不阻止清理此前已经失败或不存在的服务。

**验证：** `60` 返回预期失败；`61/62` 确认 unit、环境文件和原 target 保留；释放占用后 `63` 清理成功；`64/69` 验证缺失单元 check mode 和启动失败后的清理。归档脚本 `final/tests/juice.yml` 将此流程固化，`103b` 为 `failed=0, rescued=1`。

### 2. 中：fsname 未命中的主机仍执行公共任务

**位置：** [`../../juice.yml`](../../juice.yml) 的 `pre_tasks`。

**触发：** `-e fsname=does-not-exist`，该主机有其他实例配置，并指定一个尚不存在的缓存目录。

**证据与影响：** `45` 返回成功且 `changed=1`，`46` 确认未选中主机仍创建缓存目录。跨主机筛选时还会运行安装和监控重写流程，超出这个实例筛选的预期范围。

**归因：** `bc5c20b2` 的 playbook 预筛选仅跳过未配置主机；Gemini 收敛补丁删除了较重的跨主机 fsname 检查，也一起丢掉了未命中主机的跳过。

**修复：** 在原有 playbook 预筛选中加入“字典配置且 fsname 不在其中”条件。非字典仍交由 role 报错；不增加全局主机扫描或拼写检查。

**验证：** `65/66` 为无操作且没有创建目录；`78` 对四节点选择仅存在于 `.11` 的 `jr-odd`，recap 只有 `.11`，`changed=0`。

### 3. 中：新增 command 参数与声明的最低 Ansible 版本不一致

**位置：** [`meta/main.yml`](meta/main.yml)、[`tasks/main.yml`](tasks/main.yml)。

**触发：** 用 ansible-core 2.15.13 运行 `juice_init --check`。Gemini 加入的 `expand_argument_vars: false` 是 2.16 才提供的参数，而 role 仍声明最低 2.9。

**证据：** `58` 在 command 参数检查失败后，因为 `_fmt` 没有 `rc`，最终显示误导性的 `'dict object' has no attribute 'rc'`。新参数本身应保留：2.16+ 默认展开 `$HOME` 等变量，真实凭据不能被这种展开改变。

**修复：** 将最低版本声明更新为 2.16，并在现有第一个 assert 中检查版本。没有引入旧版本参数分支或退回不可靠的变量展开行为。

**验证：** `94` 在部署前明确提示 `juice requires ansible-core 2.16+`；`95` 用 2.16.14 对包含 `$HOME`、引号、反斜杠等字符的真实实例执行全流程，`changed=0`。2.21.5 执行完整矩阵。

## 实机测试矩阵

| 场景 | 实测结果 | 证据 |
|---|---|---|
| 四节点首次部署前 `--check`，unit 尚不存在 | 通过，没有启动/格式化副作用；软件包已由测试准备安装 | `02` |
| SQLite + 本地文件后端首次挂载 | 四节点均为正确的 `fuse.juicefs` 来源，可由 dba 写入 | `03/05` |
| 完整重跑 | 四节点 `changed=0` | `04/21/77` |
| PostgreSQL 元数据 + Silo/S3，四节点同卷 | 每台写 2 MiB 文件，四台读回四份文件的 SHA-256 一致 | `18–20` |
| PostgreSQL 同时存元数据和文件数据 | 实际格式化、挂载、2 MiB 写入/刷新成功 | `22/27` |
| Redis 元数据 + Silo/S3 | 实际挂载、2 MiB 写入/刷新成功 | `23/27` |
| 同机多实例、独立端口/路径 | 最终同时运行 11 个实例（3+3+3+2） | `76–78/118` |
| URL 密码含字面 `$HOME`，其他保留字符编码 | format、status、EnvironmentFile、systemd 全链路通过 | `24–26/95` |
| 路径、缓存、data 参数包含空格、`$HOME`、`%40`、单双引号、反斜杠 | 真实挂载和读写成功，指标保留原始字面值 | `24–26` |
| 自定义标签含 `$HOME%40` | `/metrics` 中仍为字面值，未被展开 | `25` |
| 已有元数据属于异名卷 | 明确拒绝，没有生成错误实例的 unit | `35/36` |
| format 选项无效 | 明确失败，不进入配置/启动 | `37` |
| 在 XFS bind mount 上启动失败 | 约 67 秒后真实失败，底层仍是 root、0700 | `38–40` |
| 修正启动参数后重跑 | 自动重试的实例恢复正确挂载 | `41/42` |
| 清理叠在 XFS 上的 JuiceFS | 下层 XFS 与权限保留，未误卸载宿主盘 | `43/44` |
| `juice_dir` 面对未挂载目录、错误卷 | 拒绝执行改权 | `31` |
| 在正确卷上再叠一层 tmpfs | 拒绝改权，tmpfs 保持 0700；移除测试 tmpfs 后原卷仍在 | `32–34` |
| 同一路径 old absent / new create，之后再次清理 old | 新卷正常挂载，第二次清理时 PID、启动时间不变 | `47–51` |
| 繁忙卸载 | 修复前假成功；修复后拒绝删除配置，人工释放后可清理 | `08/60–64` |
| 不存在的 unit、已启动失败的 unit | 重复清理与 check mode 均能完成 | `13/55/64/69` |
| 文档支持的各个 tags | `juice_id/install/cache/init/config/launch/dir/register/instance/juice` 均实跑；clean 另测 | `30/43/60` |
| 其他 playbook 直接引用 role、仅 `-t juice` | 动态包含任务正确执行 | `56` |
| 非法 state、端口范围/冲突、unit 冲突/后缀、路径别名/根路径/..、缓存冲突、缺 meta、非字典 | 12 组配置在变更前明确拒绝 | `53` |
| null / 空字典 | 跳过，没有引入隐式 target 清理 | `54` |
| fsname 未命中及跨主机筛选 | 修复后未命中主机无变更，只执行命中节点 | `65/66/78` |
| 修改 mount 选项后 config+launch | PID 和启动时间保持不变；显式重启后数据一致 | `70–74` |
| 杀死挂载主进程 | `NRestarts` 从 0 到 1，约 5.5 秒恢复，旧文件哈希一致 | `79–81` |
| PostgreSQL 停机 5 秒后恢复 | 进行中的新文件写入约 5.6 秒完成，校验通过，无重挂载 | `97–100-pg` |
| S3 停机 5 秒后恢复 | 进行中的写入约 14.3 秒完成，校验通过 | `97–100-s3` |
| Redis 停机 5 秒后恢复 | 修正测试服务恢复脚本后，写入约 6.7 秒完成、校验通过 | `104–106` |
| 后端离线时 `stat -f` | Redis 停止后仍可返回缓存值，不能据此判定后端在线 | `83` |
| 指标端口被外部 HTTP 进程占用 | 文件系统挂载成功、playbook 成功，但指标请求 404；释放端口并重启后恢复 | `107–111` |
| 额外 `-o fsname=custom-review` | 1.4.2 实际 source 仍为 `JuiceFS:jr-custom`，现有身份检查通过 | `112–115` |
| Victoria 实际采集 | 完整配置 11 个 active targets 全部 `up` | `118-live-targets.json` |
| node_remove 的 JuiceFS target 任务 | 单独执行实际任务，删除目标后可由 juice_register 恢复 | `90–93` |
| 全实例 absent，再重新挂载 | 所有 unit、挂载和 target 清理；重挂后本地/共享/特殊路径及其他后端文件全部保留 | `120–127` |
| 最终重复清理 | 四节点 `changed=0`；Victoria active targets 为 0，底层 XFS 保留 | `128–131` |
| 已归档的生命周期回归用例 | 实际 systemd/FUSE，`ok=95, failed=0, rescued=1` | `103b` |

共享卷四份原始随机文件的 SHA-256：

```text
10.10.10.10 d37a082402d9cfcdb3207461578a082238f6d579a3b940e5766e20c7adf52adb
10.10.10.11 c887db19949fd9aafad44e6bd4d12ea3af12d0efcb0359c9b92516cfe7f0dd85
10.10.10.12 8a6e5eb9fc7b03fd84e791bb4a22b85989106e7c24aa704a16b43604a0fa1d6a
10.10.10.13 da2389fe6efb6bf37199827b5ae9e8a113eb7e7c3fa1ea3d3dd46c2b5b42e99b
```

它们在四端读取、进程崩溃恢复、显式重启及全量清理后重新挂载时均保持一致。故障注入产生的 8 MiB 零值文件 SHA-256 为 `2daeb1f36095b44b318410b3f4e8b5d989dcc7bb023d1426c492dab0a3053e74`。

## 未扩展为代码修复的边界

1. **指标可用性独立验收。** JuiceFS 自身在显式指标端口冲突时记录错误后继续挂载。role 的成功表示所需卷已挂载，不保证指标来自正确进程。SOP 加入端口预检、`vol_name` 和 Victoria target 验收，不增加第二套进程/端口管理机制。
2. **挂载探测不等于后端可用。** `stat -f` 的缓存行为被实测确认。故障注入中的新文件创建和同步写入才会等待后端；没有给 role 增加每次重跑都写测试文件的副作用。
3. **VIBE 仍只有排序依赖。** 没有新增 Requires/BindsTo、就绪协议或故障联动。非 root 卷写入已验证，但未安装并完整启动 code-server/Jupyter，也没有重启整台沙箱验证开关机顺序。
4. **检查范围有限。** 未验证 EL/Debian、x86_64、其他 JuiceFS 版本、长时间负载、网络分区、主从切换、writeback 崩溃持久性和磁盘耗尽。node_remove 仅执行了其真实 JuiceFS target 任务，没有运行整个节点删除流程。

`findmnt` 使用系统工具，不再维护手写挂载解析器；没有为想象中的字符、路径或跨主机组合继续增加校验框架。额外 fsname 测试也推翻了“必然改变 source 导致拒绝”的预期，没有据此改动模块。

## 测试装置问题的处理

保留所有原始失败日志，没有把它们混算成模块缺陷或直接删掉：

- Debian PostgreSQL 包的 systemd 模板不能正确处理带连字符的测试 cluster 名 `juice-review`；初始化成功后改用 `pg_ctlcluster --skip-systemctl-redirect` 管理该独立后端。
- 测试 collector 的配置最初使用了其不支持的 `refresh_interval` 字段，导致 `28/29` 连接失败；删除该字段后，真实抓取在 `57/118/131` 验证。
- `systemd-run` 的 transient unit 停止后不能直接当常驻 unit 重启；测试 Redis/Silo 的恢复脚本因此失败。改为专用持久 unit，并在切换后 daemon-reload；Redis 用 `104–106` 重新完成受控中断测试。中断期间出现的 EIO/超时由这些实际后端停机解释，未归因到 role。
- 生命周期回归文件第一次执行前有一处 YAML 行内字典写法错误，`103` 尚未执行任何任务；修正后 `103b` 完整通过。
- `83` 和 `114` 的返回值与初始猜测不同，分别揭示 statfs 缓存和上游 fsname 行为，已按实测记录。

## 收尾与保留内容

最后执行了全量 absent、重新创建并验证旧文件、再次全量 absent、重复清理。四台测试 JuiceFS 已停止且挂载消失，相关 unit/环境文件和四个 target 文件已删除，实际采集目标为 0；`/data` 上原有 XFS 均保留。测试产生的单个 systemd failed 标记在留存 journal 后单独清除。

测试后端与 collector 已停止；新装 PostgreSQL/Redis 的默认服务也已停止并禁用。临时 Redis/Silo unit 已归档到 `.10` 的测试 evidence 目录后移除。原有三台 OpenBao、HAProxy、Keepalived 最终均为 `active`。

保留以下内容供复核，没有删除数据库或对象存储数据：

- 各节点 `/data/juice-review-20261111/`：SQLite 元数据、本地对象、缓存、挂载点目录；`.10` 另含独立 PG/Redis/Silo/Victoria 数据与合成数据库 dump。
- `.13` 的 `/data/juice-test-regression/`：生命周期回归的合成元数据、文件和缓存。
- 本次安装的软件包、`.10` 新增的 `juice-review-infra.list` 软件源、测试监控账号与空 target 目录；它们是测试环境准备内容，不是 role 清理应该删除的数据。
- 控制端仓库外的源码快照、inventory、脚本、执行日志和结果 JSON。

参考：[Ansible command 的版本与变量展开说明](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/command_module.html)、[JuiceFS 1.4.2 指标监听实现](https://github.com/juicedata/juicefs/blob/v1.4.2/cmd/mount.go)、[findmnt 参数说明](https://man7.org/linux/man-pages/man8/findmnt.8.html)。
