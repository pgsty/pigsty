# MySQL Beta 四节点实机测试记录

测试日期：2026-11-11。操作手册作为草稿保存在 `pigsty.cc` 文档仓库的 `content/docs/mysql/sop.md`。

## 验收结论

本轮发现三类实机问题，并用七个源码文件中的少量修改解决，没有新增任务或公开参数。
合入这些修复后，在已测范围内可以按 Beta 模块验收：EL9 / Ubuntu 24 的单机和三节点 HA 生命周期、
故障恢复与真实备份恢复通过；EL8 / EL10 / Debian 12 / Debian 13 / Ubuntu 22 的单机补充检查通过。
没有把这次功能验收扩大为全架构、生产负载或长期稳定性保证。

## 基线与范围

- 控制端：`ssh m3`，Barn 1.1.0，原生 amd64 KVM，Ansible Core 2.20.1。
- 源码：`38a67d46` 的独立副本；MySQL 最近一次提交为 `b23afb93`。
- 拓扑：`10.10.10.10` 独立实例兼监控，`10.10.10.11–13` 三节点 InnoDB Cluster。
- 每台 4 vCPU、8 GiB RAM、64 GiB 根盘、默认 128 GiB 数据盘；整机替换用例使用新根盘上的空 `/data`。
- 数据：自建 `qa.probe`，无业务数据。初始 256 行，主键和 `32896`，内容 CRC32 的异或值 `1353188270`。
- 独立测试 CA、随机口令、独立库存；未修改 m3 原有 Pigsty 工作区及服务。
- EL9 使用 Pigsty 默认的 SELinux permissive 策略；不能据此宣称 SELinux enforcing 已通过。

原始日志和脚本保存在 m3 的 `/home/vonng/pgsty/artifacts/mysql-barn-20261111/`：
`results.jsonl`、`logs/`、`scripts/`、`source/`。日志时间为 UTC。
私钥、口令库存、物理备份、安装包不进入 Git。
工件根目录的 `candidate.patch` 与 `candidate-source-sha256.json` 保存了候选修改及七个变更源码文件的 SHA-256；
已核对远端实际受测文件与本地工作区一致。

## 发现并修复的问题

### 空替换实例的 NULL Group UUID 被误判为异源集群

**级别：阻断成员替换。** 初始建群可以成功，因此仅做首装验收发现不了它。

复现流程：在健康三节点中删除当前主库，再对完整集群执行 `mysql.yml`。空实例返回
`@@GLOBAL.group_replication_group_name = NULL`、空 GTID、零业务 schema。
`inspect()` 使用 `String(NULL)` 得到 JavaScript 字符串 `"null"`，随后触发：

```text
10.10.10.12:3306 has a foreign Group Replication UUID
```

最小修复在 `templates/mysql-cluster-manage.js.j2`：将未设置的 Group UUID 归一化为空串。

```javascript
group: String(scalar(s, "SELECT @@GLOBAL.group_replication_group_name") || ""),
```

没有放宽真实非空 UUID 的异源检查，也没有增加参数或任务。

证据：`el9-replace-removed-member.log` 是修复前失败；`el9-27-replacement-null-fix.log` 是原现场修复成功。
`el9-28-primary-remove-reclone-fixed.log` 又删除了另一个运行时主库，验证移交、重复删除、Clone、数据一致与重跑。
`el9-29b-replace-whole-vm.log` 验证原地址整机替换：新根盘、脱离旧数据盘、重新安装、Clone 和重跑全部成功。

### MySQL Shell 在脚本执行前读取默认配置并尝试无密码连接

**级别：阻断 Ubuntu HA 首次部署。** Ubuntu 的系统配置包含 Pigsty 的 `[client]` 选项。
原命令 `mysqlsh --js --file ...` 在执行脚本前就读取这些默认值并尝试连接，出现：

```text
Access denied for user 'root'@'localhost' (using password: NO)
```

相同凭据通过 MySQL 客户端可正常登录；直接给 Shell 添加 `--no-defaults` 后，脚本连接成功。
修复是在实例配置、集群协调、单成员离群和 `mysh` 四个入口统一添加这个选项。
脚本已明确提供连接地址、TLS 和凭据，不需要继承系统客户端默认配置。

证据：`u24-mysql-install.log` 是原失败，`u24-01-shell-defaults-fix.log` 是原现场恢复成功。

### exporter 密码编码与 MySQL 客户端的规则不同

**级别：特殊密码下监控失效，剧本本身不报错。** 同一个原始配置用 MySQL 客户端登录成功，
mysqld_exporter 却返回 1045、`mysql_up=0`。原模板把反斜杠按 MySQL 客户端规则加倍，
但 exporter 的 go-ini 解析器不会作相同还原；它还会展开 `$` 环境变量和 `%(...)s` 插值。

修复使用 go-ini 原样三引号值，并将字面量 `$` 编码为 `$$`。对不能原样表达的 `%(...)s`，
在现有参数校验中添加一条拒绝规则，没有新增任务或参数。
解析依据为 [exporter v0.21.0](https://github.com/prometheus/mysqld_exporter/blob/v0.21.0/config/config.go)
和 [go-ini v1.67.3](https://github.com/go-ini/ini/blob/v1.67.3/parser.go)。

证据：`u24-02-baseline.log` 检出采集失败，`u24-03-monitor-password-fix.log` 修复后四节点采集恢复。
`u24-09-exporter-passwords.log` 进一步复现 INI 插值导致的密码变化；
`u24-09b-exporter-passwords.log` 验证引号（含三引号）、反斜杠、美元变量形式、空白、中文、普通百分号均可用，
INI 插值在改动数据库或 exporter 前即被拒绝，随后恢复原监控口令并重新采集成功。

## EL9 结果

实测包版本：MySQL Server `8.4.13-1.el9`，Shell / Router `8.4.10-1.el9`，
XtraBackup `8.4.0-7.1.el9`，mysqld_exporter `0.21.0-1PGSTY`。

下面每行描述独立场景；没有把脚本外层与内层的重复记录累计成“用例数”。

| 场景 | 结果与检查点 | 主要日志 |
|---|---|---|
| 全新四节点安装 | 通过；独立实例与三节点集群均上线，实际安装约 84.7 秒 | `el9-09-mysql-install` |
| 基本身份与路径 | `/data/mysql`，无幽灵 `/var/lib/mysql/mysql`，server UUID 与复制状态可读 | `el9-10-baseline` |
| TLS 与入口 | 明文 TCP 拒绝；三个 Router 的 6446/6447 分别连接主/从；exporter 全部正常 | `el9-10-baseline` |
| 非法库存与存储守卫 | 14 项拒绝测试通过，前后 mysqld PID 不变 | `el9-14-guards-corrected` |
| 完整检查模式与重跑 | 通过；正常实例 PID 保持不变 | `el9-15-rerun-pids` |
| 备份资格与互斥锁 | 从库跳过；锁竞争跳过；旧指标保留 | `el9-16-backups` |
| 首次备份失败和重试 | 写零时间指标、清理 partial；重跑备份标签后实际成功 | `el9-16-backups` |
| 已有备份后的失败 | 旧 `latest` 与成功时间保留；journal 给出详细日志位置 | `el9-16-backups` |
| 备份保留和开关 | 多次备份后恰有 3 份 committed 备份；不删未提交 canary；关闭后 timer/指标清理 | `el9-16-backups` |
| 真实磁盘满 | 2 MiB tmpfs 引发 ENOSPC；不提交残缺备份；旧备份与指标不变 | `el9-32-disk-full` |
| 物理恢复 | 删除 10 行后从真实 XtraBackup copy-back，256 行及两项校验值完全恢复 | `el9-19-physical-restore` |
| 主动切换 | 切到 seq=2/3 后重跑，保留运行时主库；Router 最终指向新主库 | `el9-18-ha-switchover-convergence` |
| 分阶段配置与滚动重启 | config 阶段 PID 不变；launch 阶段逐成员重启；三个实例均应用 `max_connections=1101` | 同上 |
| 主库 SIGKILL | 多数派约 21.65 秒选主；旧节点回归后停机期间写入的数据一致 | `el9-20-primary-crash`、`el9-20b-crash-recovery` |
| 降级 provisioning | 只对可达的实际主库执行成功 | `el9-degraded-provision` |
| 全集群停机 | 自动重启并恢复三个 ONLINE，实例身份和数据保留；剧本约 126.5 秒 | `el9-21-complete-outage` |
| 主库网络隔离 | 多数派约 21.8 秒选主并写入；少数派没有成功确认；协调拒绝 NO_QUORUM；解除隔离后数据一致 | `el9-23-partition` |
| 无效 MySQL 参数 | validate 拒绝；旧配置内容和 PID 不变；候选临时文件清理 | `el9-25-objects` |
| 特殊密码与增量对象管理 | 引号、反斜杠、美元符号、反引号、空格、中文密码登录成功；删除声明不删对象 | `el9-25-objects` |
| 主库删除与原机重建 | 先移交主库；重复删除成功；备份保留；Clone 后 UUID 更新且数据一致 | `el9-28-primary-remove-reclone-fixed` |
| 同地址整机替换 | 新根盘、空数据路径重新安装并 Clone，三节点健康，数据一致，重跑通过 | `el9-29b-replace-whole-vm` |
| seq=1 数据落后的全集群恢复 | seq=1 缺少最新事务，AdminAPI 从 seq=2 恢复；259 行及校验和一致 | `el9-30-latest-gtid-seed` |
| 保留数据停机再恢复 | 完整集群 `mysql_rm_data=false` 后重跑，所有 UUID 与数据保留 | `el9-31-stop-keep-data` |
| 分叉 GTID | 三个停复制成员分别写入不同本地事务；自动恢复拒绝，三个本地分支未被覆盖 | `el9-33b-divergent-gtid` |
| 完整删除和卸载 | 默认清理、空/缺失目录重试、追加卸载软件包全部通过；本地备份保留 | `el9-34-full-remove` |
| 真实备份过期告警 | 修改测试时间指标为 0，约 390 秒 firing；恢复指标后约 90 秒消退 | `el9-24-monitoring` |
| 真实 exporter 停机告警 | 停服务后约 180 秒 firing；恢复服务后约 60 秒消退 | `el9-24-monitoring` |

14 项拒绝测试分别覆盖：HA 部分部署范围、重复序号、`..` 路径、备份与数据目录重叠、
覆盖平台 datadir、覆盖 GR 参数、参数换行、HA 集群口令隐式轮换、默认删除保护、一次删除两个成员、
单成员保留数据删除、异源 marker、datadir 挂载点、含隐藏文件的未托管目录。

## Ubuntu 24 结果

全新四节点，MySQL Server `8.4.13-1ubuntu24.04`，Shell / Router `8.4.10-1ubuntu24.04`，
XtraBackup `8.4.0-7-1.noble`，mysqld_exporter `0.21.0-1PGSTY`。
本轮 root、集群和监控口令均包含引号、反斜杠、美元符号、反引号、空格和中文。

| 场景 | 结果与检查点 | 主要日志 |
|---|---|---|
| 实机 AppArmor | 四台 mysqld、三台 Router 的实际进程均为 enforce；配置校验、证书读取、Clone 和 mysh 可用 | `u24-08b-apparmor` |
| 首装与故障续跑 | 原版 Shell 入口失败；添加 `--no-defaults` 后从中断现场继续建群成功 | `u24-mysql-install`、`u24-01-shell-defaults-fix` |
| TLS、路径、Router、复制 | 修复监控密码编码后全部通过，三节点 256 行及校验和一致 | `u24-02b-baseline` |
| 重跑幂等 | 检查模式和实际重跑通过，四个 mysqld PID 不变 | `u24-03-rerun` |
| 切主与滚动重启 | Router 收敛，重跑保留新主库，分阶段配置生效，数据一致 | `u24-04-switchover-rolling` |
| 主库 SIGKILL | 约 26.25 秒选出新主库；降级写入、provisioning、旧节点回归均通过 | `u24-05-primary-crash` |
| 删除当前主库、重复删除与 Clone | 新 UUID，保留备份，数据一致，再次重跑成功 | `u24-06-primary-remove-reclone` |
| 全集群停机恢复 | 约 129 秒完成整个测试流程，恢复三个 ONLINE 与 Router，数据一致 | `u24-07-complete-outage` |
| exporter 特殊密码 | 多类特殊字符采集正常，INI 插值提前拒绝 | `u24-09b-exporter-passwords` |
| 物理恢复 | 实际删除 10 行、copy-back、启动并验证，恢复初始 256 行和校验和 | `u24-10-physical-restore` |
| 无效配置和业务对象 | 旧配置、PID 保持不变；特殊字符业务密码与增量对象管理通过 | `u24-11-objects` |
| exporter 开关 | 关闭后服务停止、file-SD 为 `[]`；重新启用恢复目标和 `mysql_up=1` | `u24-12-exporter-toggle` |
| 14 项参数与删除守卫 | 均在预期边界拒绝；mysqld PID 保持不变 | `u24-13-guards` |
| 备份故障回归 | 首次失败重试、后续失败保留、并发锁、保留数量、开关全部通过 | `u24-14-backups` |
| 完整删除与卸载 | 空/缺失目录重复清理、卸载软件包通过；本地备份保留 | `u24-15-full-remove` |
| 最终候选从零安装 | 再次 purge 后新建四节点；MySQL 安装约 87.4 秒，四台均为 failed=0、ignored=0 | `final-u24-mysql-install` |
| 非空替换节点防覆盖 | 脱离集群后创建独立 canary 数据与 GTID；协调拒绝 Clone，原有数据和 GTID 保持不变 | `final-u24-nonfresh` |

拒绝覆盖后，通过显式清理再 Clone 恢复了第三个成员，三节点重新一致。最终完整重跑仍保持 mysqld PID 不变。

## 补充平台矩阵

使用四个独立实例检查包、路径、备份和清理差异。这部分不替代对应平台的三节点 HA 验证。
四个平台实测 Server 均为 MySQL `8.4.13`。

| 系统 | 数据路径 | 首装、写入、备份、exporter | 重跑 PID 不变 | 删除、重复卸载、备份保留 |
|---|---|---|---|---|
| EL8 | `/data/mysql` | 通过 | 通过 | 通过 |
| EL10 | `/data/alt-mysql` | 通过 | 通过 | 通过 |
| Debian 12 | `/var/lib/mysql` | 通过 | 通过 | 通过 |
| Debian 13 | `/data/mysql` | 通过 | 通过 | 通过 |
| Ubuntu 22 | `/data/mysql` | 通过，AppArmor enforce | 通过 | 通过 |

证据：`matrix-03-other-os-install.log`、`matrix-07-el8-install.log`、`matrix-09-platform-checks.log`。
EL8 使用 Ansible Core 2.16.14，其余使用 2.20.1。混合控制端测试中，新版 Ansible 向 EL8 监控节点
委派文件操作会遇到 Python 3.6 不兼容，相关任务为 `ignored`；用兼容入口执行的
`matrix-08-register.log` 已完成四个目标注册。表中结论仅涵盖列出的检查；完整监控闭环以 EL9/Ubuntu 24 为准。
Ubuntu 22 使用单独重建的第四个节点，证据为 `u22-00-smoke.log`；它沿用 `my-d13` 测试组名，系统实际已换成 Ubuntu 22。

## 操作时需要知道的行为

- Router 开启 `use_gr_notifications=1` 后，实际配置为 `ttl=60`。全停恢复时通知连接消失，
  数据库在 `08:11:14–18 UTC` 恢复，Router 在 `08:11:58` 的后备轮询才重新开放端口。
  这次在现有重试窗口内通过；不能把“mysqld 已启动”当成“6446 已可用”。暂未增加新参数或改动默认 TTL。
- vmalert 的多层记录规则每 30 秒评估，监控和告警有传播延迟。首次部署时健康记录曾暂时为 0，
  后续收敛为正常值；告警时长还需叠加采集与记录规则传播时间。上述耗时是单次实测，不是 SLA。
- 备份是本地全量物理备份。主库切换不会迁移旧主机上的备份；Barn purge 会连同数据盘备份一起销毁。
- 少数派写入超时代表没有获得成功确认，不能泛化为所有超时事务都一定未提交。
  本次特定测试行在恢复后的全部成员上均不存在。

## 测试脚本与环境问题的归因

原始结果保留失败记录，以下不计为 MySQL 模块缺陷：

- 初次 CA 命令选择了库存中不存在的 localhost；改用 `-i localhost, -c local` 后完成。
- Barn purge 初次 120 秒超时碰到关机宽限期；放宽测试超时后完成。
- 新环境 node/infra 检查模式无法实际创建软件源、目录和符号链接依赖；实际前置安装成功。
- “禁止 HA 集群口令轮换”的测试最初误选独立实例；改为完整 HA 范围后正确拒绝。
- 最初的切换/崩溃测试要求 Router 零延迟收敛；改为等待并记录收敛时间后，相关检查通过。
- Barn 不支持对单节点传入 `--delete-persistent`；改用新根盘并脱离旧数据盘，完成整机替换。
- MySQL Shell 的真实 GTID 冲突错误含上游拼写 `GTID conflits`；最初测试只匹配 `conflicting`，
  导致外层断言失败。数据库已正确拒绝恢复，后续根据实际错误与数据库状态验证。
- Ubuntu Router 使用 SysV 兼容单元，服务运行时 `systemctl show MainPID` 仍可能为 0；
  AppArmor 检查改为读取实际 Router 进程的 `/proc/<pid>/attr/current`，不把 0 当作进程不存在。
- EL8 镜像默认 Python 3.6，m3 的 Ansible Core 2.20 在采集 facts 时即失败。
  用工件目录中的 Python 3.12 / Ansible Core 2.16.14 / Ansible 9.13 隔离环境继续测试，
  没有改动 MySQL 源码来兼容控制端。`scripts/ansible-el8` 保存了可复用入口。

## 尚不涵盖的保证

这不是负载、长稳、性能或生产可用性认证。当前不据此宣称 ARM64、跨版本升级、SELinux enforcing、
离线仓库、VIP、外部通知投递、异地备份、PITR 或整个 InnoDB Cluster 的物理备份重建已经通过。
物理 copy-back 只验证独立实例；三节点恢复验证的是原数据恢复、增量回归及 Clone 替换。

## 最终保留环境

2026-11-11 09:08 UTC（北京时间 17:08）最后验收通过，证据为 `final-health.log` 和 `logs/final-state.json`。

- 四台 Ubuntu 24 KVM 虚拟机运行中，`my-meta` 为独立实例。
- `my-test` 三个成员全部 ONLINE，当前主库为 `10.10.10.11`，三个 Router 的读写端口验证通过。
- 四个 `mysql_up=1`，textfile 采集无错误，两个集群健康记录均为 2，备份时间均在一小时内。
- 独立实例和当前主库已再次完成真实备份，四个实例均保留 256 行测试数据及相同校验和。
- mysqld 与 Router 在 AppArmor enforce 下运行；没有遗留故障注入的备份包装器或临时测试挂载。
- 源码修复与本报告保存在 Pigsty 代码仓库；操作手册草稿位于 `pigsty.cc` 文档仓库，原始测试脚本与日志保留在 m3 工件目录。
