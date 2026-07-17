# Pigsty Kafka 生产设计：两轮对抗性评审记录

> 评审对象：`roles/kafka/DESIGN.md`
>
> 第一轮评审模型：Claude Code `claude-fable-5`
>
> 第一轮会话：`13f1cd04-745b-4100-a227-406cc62daaf8`
>
> 第一轮完成时间：2026-07-16

## 1. 评审规则

评审不是功能愿望清单。双方共同遵守两个约束：

1. 生产正确性优先，不能用简化 API 掩盖错误的 Kafka 语义；
2. 公共 API 具有高昂复杂度成本，不能为了理论覆盖率增加变量。

Claude 第一轮只允许读取仓库和官方资料，不允许修改文件。要求它重点攻击角色、KRaft
quorum、listener、安全 bootstrap、Cluster ID、复制参数、Topic/User schema、Exporter
部署和滚动状态机。

Codex 对每一项只能选择：

- 接受：批评成立，按最小修正纳入最终设计；
- 部分接受：失败场景成立，但修正方式或技术归因需要调整；
- 反驳：有明确范围、事实或复杂度理由，不接受该修改。

## 2. Claude 第一轮总体裁决

Claude 给出的结论是“有条件通过”：角色语义、API 裁剪、包契约、幂等 format 和监控方向
正确，但设计缺少一个核心边界：

> 可持续收敛的期望配置，与 bootstrap 后冻结的集群事实，不是同一类状态。

它认为安全模式、quorum 模式、初始复制策略和 Cluster ID 不能在每次 Ansible 运行时根据
inventory 无条件重算。这个总批评成立。

## 3. Claude 第一轮问题清单

### F1：单 BROKER listener 无法直接滚动完成 plaintext 到 scram 的迁移

Claude 指出，既有集群若直接把同一端口从 PLAINTEXT 改为 SASL_SSL，第一个重启节点会与
旧协议节点失去 inter-broker 通信；Controller 同时切换 mTLS 还会破坏 quorum。安全协议
迁移通常需要临时增加 listener、滚动切换 `inter.broker.listener.name`，再移除旧 listener。

建议：把 `kafka_security` 定义为 bootstrap 后不可直接修改的属性；在线迁移另做显式
admin 流程。

### F2：RF/minISR 按当前 broker count 持续重算会制造危险漂移

Claude 给出的失败例是：单 Broker 时 `__transaction_state` 以 RF=1 创建；扩到三 Broker
后静态参数被重算为 minISR=2，但既有内部 Topic 的 RF 仍是 1，事务写入会失败。

建议：初始 RF/minISR 只在 bootstrap 时确定并冻结；扩容只报告实际状态差异，提升内部
Topic RF 必须通过显式 reassignment。

### F3：Kafka 4.3 ELR 要求 cluster-level minISR 管理

Kafka 4.3 新集群默认启用 ELR。官方文档说明：ELR 开启后，broker-level
`min.insync.replicas` 会被移除且不能修改；cluster-level minISR 不能删除，重复更新也会
清空 ELR 状态。

建议：不必增加新的公共参数，但 role 内部必须有动态 cluster config 收敛层；
`min.insync.replicas` 不允许通过静态 `kafka_parameters` 设置。

### F4：统一严格滚动门禁会让 bootstrap 和冷启动自锁

新建三 Controller 集群时，第一个节点启动后还没有多数派，无法通过 quorum 健康检查；
如果检查失败就停止，后续节点永远不会启动。全集群冷启动和修复故障节点也有同类问题。

建议：内部状态机区分 bootstrap、cold-start/repair、rolling 三类路径。只有健康运行集群的
rolling 路径执行严格前后门禁。

### F5：静态 quorum voters 不能随 inventory 改变

当前实现每次从 inventory 重算 `controller.quorum.voters`。静态 quorum 的成员集合不是
普通配置，新增 Controller 后改写所有节点配置并不能安全完成成员变更。

Claude 建议：冻结静态 voters；动态 quorum 和成员管理推迟到 P1。

### F6：仅由 `kafka_cluster` 确定性生成 Cluster ID 不足以防错

同名 dev/prod 集群会得到相同 Cluster ID；同名集群销毁重建后，残留旧盘可能通过
cluster/node identity 校验。

建议：随机生成并持久化 Cluster ID，或至少加入部署级 salt；保留显式
`kafka_cluster_id` 作为接管/恢复接口。

### F7：scram 模式缺少内部 Principal bootstrap 链路

需要明确 inter-broker、admin、kafka_exporter 等内部 Principal。inter-broker SCRAM 凭据
必须在安全集群首次启动前存在；deny-by-default 也要求监控 Principal 先获得最小 ACL。

建议：secure bootstrap 时预置内部凭据和 ACL；健康门禁优先读取 JMX，避免依赖 Kafka
协议管理员凭据。

### F8：`kafka_users` 缺 TransactionalId/Cluster，`superuser` 是错误抽象

事务 Producer 需要 TransactionalId ACL。用户级 `superuser` 最终映射到静态
`super.users`，用户变更会意外要求全集群滚动。

建议：ACL resource 支持 Topic、Group、TransactionalId、Cluster；删除用户对象的
`superuser`，只保留 role 内部 bootstrap admin。

### F9：`kafka_topics` 没有定义危险变更语义

减少 partition 不受支持；改变 replication factor 需要 reassignment；删除 Topic 是破坏性
操作。只给创建 schema 会让用户误以为所有字段都能普通收敛。

建议：partition 只增；v1 拒绝 RF 修改；删除不进入声明式列表，使用独立显式动作。

### F10：每个 Broker 抓一份 kafka_exporter 集群全量指标不能无限扩展

20 Broker 会产生 20 份 Topic/Partition/Consumer Group 序列，并重复查询 Kafka metadata
和 offsets。要求所有 Dashboard/Alert 永远记得去重也很脆弱。

建议：unit 可以全装，但只注册 `kafka_seq` 最小的两个 broker-capable 节点；或者只允许
Dashboard/Alert 使用去重后的录制规则。

### F11：混合拓扑中默认 combined 可能静默增加 Controller

在 3 Controller + N Broker 拓扑中，扩容 Broker 时漏写 role，会按默认 combined 进入
控制面。

建议：只要同集群任一主机显式设置 role，则全部主机都必须显式设置。

### F12：rack awareness 被裁掉过头

三 Broker、RF=3 时副本自然覆盖全部 Broker；但多于 RF 个 Broker 且跨故障域时，没有
`broker.rack` 就不能保证一个分区的副本跨 AZ。

建议：至少声明限制；最终增加 host-level `kafka_rack`。

### F13：`hosts: all` + `serial: 1` 跨集群耦合且不表达角色顺序

建议：启动/滚动按状态与角色拆分，并要求一次 play 明确限制单一 Kafka 集群。

### F14：删除 advertise address 且禁止 raw override 使云网络没有逃生口

Claude 认为 `advertised.listeners` 是云环境常见需求，建议恢复
`kafka_advertise_address`，或从 `kafka_parameters` 黑名单移除
`advertised.listeners`。

### F15：Claude 认为仍应删除或恢复的 API

Claude 还提出：

- 删除 `kafka_jmx_exporter_enabled`，因为 JMX 是滚动健康门禁的承重能力；
- 删除 `kafka_users[].superuser`；
- 不为未发布的旧 API 写专用迁移/兼容测试；
- 恢复 `kafka_exporter_options`，作为 Topic filter 等高基数控制的逃生舱；
- 保留 `kafka_cluster_id` 高级覆盖、`kafka_heap_opts` 和 `kafka_parameters`。

## 4. Codex 第一轮对抗性回应

### C1：部分接受 F1——冻结是模块契约，不是 Kafka 的绝对 format 事实

接受失败场景和最终约束：v1 中 `kafka_security` 是 bootstrap-only。已格式化集群直接改变
安全模式必须 fail-fast。

但需要纠正技术归因：SCRAM client credential 可以在集群启动后动态创建；Kafka 本身也
支持通过临时 listener 完成协议迁移。因此“安全模式天然在 format 时不可变”不准确。
不可变是 Pigsty v1 在“单 BROKER listener、无迁移状态机”约束下作出的产品契约。

最终决策：

- 新集群可以选择 plaintext 或 scram；
- bootstrap manifest 记录安全模式；
- 普通 `kafka.yml` 不允许改变；
- 后续若实现在线迁移，作为显式 admin 动作临时增加 listener，不扩展稳态公共 API。

### C2：接受 F2——复制策略必须 bootstrap 冻结

初始 broker 数用于计算默认 RF/minISR，但结果进入 bootstrap manifest，而不是每次从
inventory 重算。扩容后 role 对比实际内部 Topic，只报告 drift，不自动提高 minISR。

内部 Topic RF 提升、数据迁移和 broker drain 属于显式 reassignment 生命周期。

### C3：接受 F3——增加内部配置层，不增加公共参数

官方 4.3 ELR 文档证实该问题。最终设计区分：

1. 静态 node/server 配置；
2. role 拥有的动态 cluster 配置；
3. Topic 配置。

`kafka_parameters` 仍只作为高级 server 参数入口；`min.insync.replicas` 加入黑名单。role
只在 bootstrap/provision 的正确时机设置 cluster-level minISR，不能在每次重跑时无意义
重复写入，避免清空 ELR 状态。

不增加 `kafka_cluster_parameters`，因为当前只有受 role 管理的 minISR 构成必需场景。

### C4：接受 F4——门禁必须是内部三态状态机

状态由现场推断，不增加用户开关：

- bootstrap：没有已形成的集群，先格式化/启动 Controller quorum，再统一验收，然后启动
  Broker；
- cold-start/repair：已有 metadata 但集群不可达，允许恢复 Controller 多数派或目标节点；
- rolling：集群健康，严格执行目标节点排除后的 pre-check、单节点变更、catch-up 和
  post-check。

“JMX disabled”时不能假装仍有同等门禁；实现应使用 Kafka CLI/metadata quorum fallback，
生产文档要求 JMX enabled。

### C5：反驳 F5 的修正方式——Kafka 4.3 新集群直接使用动态 quorum

Claude 正确指出静态 voters 不能持续重算，但“先冻结静态 voters、动态 quorum 放 P1”仍然
保留了不必要的历史包袱。

Kafka 4.3 官方文档把静态 quorum 称为 old way，并推荐动态 quorum；
`controller.quorum.voters` 在 kraft.version=1 已弃用。Beta 模块没有任何理由创建一批未来
必须迁移的静态集群。

最终决策：

- 新集群只使用 `controller.quorum.bootstrap.servers`；
- 初始 Controller 使用 `--initial-controllers` 或受控的 standalone + add-controller 流程；
- 初始 Controller directory ID 与 Cluster ID 存入 bootstrap manifest；
- 新 Broker 使用 `--no-initial-controllers` format；
- 新 Controller 不因出现在 inventory 就自动入会，必须经过 catch-up + add-controller
  admin 流程；
- 不增加 `kafka_quorum_mode` 参数。

### C6：接受 F6——Cluster ID 改为随机并持久化

删除“对集群名做 hash”的实现。新集群使用 `kafka-storage.sh random-uuid` 或等价随机 ID，
与动态 quorum 所需 Controller directory IDs 一起存入 admin 上的 cluster bootstrap
manifest。

`kafka_cluster_id` 仍保留为接管/恢复的高级输入，但不出现在普通样例，也不在 defaults 中
制造日常认知负担。

manifest 不包含明文业务用户密码；敏感内部凭据使用独立 mode 0600 的 secret material。

### C7：接受 F7——明确内部 Principal 与顺序

scram bootstrap 至少需要：

- inter-broker Principal；
- Pigsty admin Principal；
- kafka_exporter monitoring Principal。

Controller 使用 Pigsty CA 签发的双向 TLS 身份。inter-broker/admin 初始 SCRAM credential
必须在首次 Broker 启动前写入 metadata；监控 ACL 在 deny-by-default 对外生效前创建。

这些都是 role-owned identities，不增加用户名、JAAS path 或证书 path 公共变量。

### C8：接受 F8——删 `superuser`，补原生资源

用户 ACL 支持：Topic、Group、TransactionalId、Cluster。Pigsty 内部 admin 是唯一默认
superuser，不作为普通 `kafka_users` 对象管理。

host ACL 与 client-id quota 暂不进入 v1 schema；这是明确的范围限制，不用通用 map 伪装
完全覆盖。

### C9：接受 F9——Topic schema 必须定义单调性

- create：幂等；
- partitions：只允许增加；
- replication factor：v1 普通收敛拒绝修改，输出 reassignment action；
- config：只收敛明确声明的键；
- delete：不由“从列表移除”触发，必须独立危险操作。

### C10：接受 F10 的容量批评，采用固定两个 Exporter 副本

最终约定：只在按 `kafka_seq` 排序后的前两个 broker-capable 节点启动并注册
kafka_exporter；单 Broker 集群只有一个。无论集群有多少 Broker，协议指标采集成本最多
2 倍。

选择两个而不是一个是为了监控可用性；不增加 placement、replica count 或 enabled 参数。
Dashboard 总览使用 cluster-level 去重录制规则；实例面板明确展示 Exporter replica 自身，
不得把它解释成 Broker 节点指标。

### C11：接受 F11——混合拓扑必须全显式

- 集群中无人写 role：全部 combined；
- 只要任一节点显式写 role：全部节点必须显式写 role；
- 缺失即 validation failure。

这保留极简三 combined 样例，同时阻止 split topology 扩容时静默加入 Controller。

### C12：接受 F12——`kafka_rack` 是少数真正必要的新参数

仓库没有可复用的 node rack/zone 稳定语义。对于 broker 数量大于 RF 的多故障域生产集群，
`broker.rack` 无法从 inventory IP 推导，也不能可靠地塞进会整体覆盖的 host-level
`kafka_parameters`。

因此 `kafka_rack` 通过 API 准入测试：host-level、可选、只在 broker-capable 节点渲染。
三节点 combined 不要求填写；多故障域生产验收必须填写并验证 rack 分布。

### C13：接受 F13 的隔离要求，不预设错误的统一角色顺序

一次生命周期操作必须明确限制一个 Kafka 集群。bootstrap 先形成 Controller quorum 再启动
Broker；rolling 的具体顺序由角色和健康状态决定，不能只靠 inventory 顺序或一句固定的
“controller-first”。

不增加 rollout strategy 参数。

### C14：反驳 F14——不恢复 advertise address，也不放行结构键

用户已明确要求删除 `kafka_advertise_address`。这一决定与 Pigsty inventory 模型一致：

- `inventory_hostname` 是 Kafka 对外公布的稳定节点名；
- SSH/管理平面可用独立的 `ansible_host`；
- DNS、路由和 split-horizon DNS 解决地址可达性；
- 多网络、多 listener、NAT 映射不属于 v1 核心承诺。

也不允许 `kafka_parameters` 覆盖 `advertised.listeners`。它是 role-owned 结构配置，raw
override 会与角色、安全模式和监听器渲染发生冲突。逃生舱不是绕过所有结构不变量的后门。

如果未来出现经过验证且 DNS/路由无法解决的需求，再设计结构化 listener API；当前不为
假设场景增加变量。

### C15：反驳删除 JMX enabled

保留 `kafka_jmx_exporter_enabled`，原因包括：

- 用户已确认 enabled 与 port 是合理 API；
- Pigsty 支持不部署完整 infra/monitor 的极简环境；
- Java agent 和额外端口是用户有权明确关闭的运行面；
- “关闭后不再满足 production monitoring 基线”可以由文档和 preflight 表达，不意味着
  必须删除开关。

生产滚动不能只实现 JMX 一条路径；disabled 时必须用 Kafka CLI/metadata API fallback。

### C16：接受删除旧 API 专用迁移机制

不保留 alias，不扫描并专门报错旧变量，也不维护 controller-only 的迁移 fixture。角色枚举
正常校验非法值即可。Beta 未发布 API 不值得专门维护“旧名墓碑”。

### C17：反驳恢复通用 `kafka_exporter_options`

不恢复。理由：

- 任意 CLI bag 是不稳定、难验证的低质量 API；
- Exporter 数量已经固定为最多两个，解决了主要放大问题；
- TLS/SCRAM 参数由安全模式生成，用户不应重复拼装；
- 若未来真实集群证明 Topic/Group filter 必需，应增加有语义、可测试的 typed filter，
  而不是恢复无限制 options。

`kafka_exporter_kafka_version` 继续内部化为包兼容契约。

## 5. 第一轮收敛结果

| 议题 | Claude 第一轮 | Codex 回应 | 进入第二轮的结论 |
|---|---|---|---|
| 三值 role | 保留 | 同意 | 保留 |
| 默认 combined | 加混合拓扑约束 | 同意 | 全默认或全显式 |
| 双 listener | 有条件保留 | 同意 | 稳态保留，安全模式 bootstrap-only |
| advertise override | 恢复逃生口 | 反驳 | 删除且禁止 raw override |
| quorum | 冻结静态，动态 P1 | 反驳并前移 | Kafka 4.3 新集群直接动态 quorum |
| Cluster ID | 随机持久化 | 同意 | 随机 + bootstrap manifest |
| RF/minISR | bootstrap 冻结 | 同意 | 冻结；扩容显式 reassignment |
| ELR config 层 | 内部增加 | 同意 | 内部动态 cluster config，无新 API |
| 启动/滚动 | 三态状态机 | 同意 | bootstrap/cold-start/rolling |
| SCRAM principals | 明确内部链路 | 同意 | inter-broker/admin/monitor |
| User schema | 补资源、删 superuser | 同意 | 采纳 |
| Topic 变更语义 | 补充 | 同意 | 采纳 |
| kafka_exporter | 限制副本 | 同意 | 最多两个派生副本 |
| kafka_rack | 最终应加入 | 同意 | 新增唯一 host placement 参数 |
| JMX enabled | 删除 | 反驳 | 保留，生产要求 true |
| exporter options | 恢复 | 反驳 | 继续删除 |
| 旧 API 墓碑测试 | 删除 | 同意 | 不增加 |

## 6. 第一轮引用的官方事实

- Kafka 4.3 KRaft：<https://kafka.apache.org/43/operations/kraft/>
- Kafka 4.3 ELR：<https://kafka.apache.org/43/operations/eligible-leader-replicas/>
- Kafka 4.3 SASL/SCRAM：<https://kafka.apache.org/43/security/authentication-using-sasl/>
- Kafka 4.3 Broker Configs：<https://kafka.apache.org/43/configuration/broker-configs/>
- Kafka 4.3 Basic Operations / rack awareness：
  <https://kafka.apache.org/43/operations/basic-kafka-operations/>

## 7. Claude 第二轮复审

第二轮继续使用同一 `claude-fable-5` 会话，重新读取修订后的 `DESIGN.md` 与本文件中的
Codex 回应。Claude 的总体判断是：公共 API 已经收敛，只剩边界规则和实现约束需要补写。

### 7.1 对 Codex 主要反驳的裁决

| 争议 | Claude 第二轮裁决 | 最终结果 |
|---|---|---|
| 新集群直接 dynamic quorum | 同意 Codex，撤回 static-first | dynamic-first |
| 删除 advertise override | 接受 scope，撤回恢复要求 | 删除且禁止 raw override |
| 保留 JMX enabled | 同意 Codex，撤回删除要求 | 保留；门禁与 JMX 解耦 |
| 不恢复 exporter options | 同意 Codex，撤回恢复要求 | 继续删除 |
| 最多两个 kafka_exporter | 同意，要求处理 de-selection | 两个派生副本并清理旧 unit/target |
| 新增 `kafka_rack` | 同意 | broker-capable 全有或全无 |
| 安全模式 bootstrap-only | 同意，并接受产品契约归因 | 普通 playbook 不支持在线切换 |
| converge/rolling 状态机 | 部分同意 | 一个健康谓词决定两条实现路径 |

### 7.2 Claude 撤回或修正的第一轮意见

1. 撤回“冻结静态 quorum，dynamic quorum 放 P1”。Kafka 4.3 新模块直接 dynamic 更正确，
   static-first 只会制造未来迁移负担。
2. 撤回“必须恢复 advertise 逃生口”。删除是明确范围决定，将来增加是纯增量。
3. 撤回“删除 `kafka_jmx_exporter_enabled`”。admin 通道无论如何都存在，门禁不需要依赖
   JMX；开关只影响可观测性。
4. 撤回“恢复 `kafka_exporter_options`”。固定两副本消除了主要放大项，typed filter 是更好
   的未来扩展方式。
5. 修正“所有派生复制值全部冻结”：`default.replication.factor` 只影响未来 Topic，可以
   随当前 broker count 收敛；会改变既有对象行为的 RF/minISR 才冻结。
6. 接受 Codex 对安全归因的纠正：bootstrap-only 是 Pigsty v1 产品契约，不是 Kafka 永久
   不支持在线迁移。

### 7.3 第二轮要求补齐的边界

Claude 指出以下内容不会改变 API，但必须写入最终设计：

- bootstrap manifest 只保存 Cluster ID、initial Controller identity、安全模式和初始复制
  策略；活集群是运行事实权威；manifest 丢失时可从健在集群重建；旧 manifest 配合空盘
  时必须 fail-closed；
- Pigsty 全仓库以 inventory key 为节点 IP 的主约定，不能把“DNS inventory + ansible_host”
  写成未经测试的逃生承诺；最终明确要求客户端可路由 inventory 地址；
- 健康门禁只维护 role-owned admin API/CLI 一条实现，JMX 只用于监控；
- Controller directory ID 与 quorum 记录不一致代表成员身份变化，不能按普通磁盘修复；
- 实现只需判断“quorum 当前是否健康”：健康进入 rolling，否则进入统一 converge；
- 所有节点 format 必须显式选择 dynamic flag；单 combined 不能仅靠重跑普通 playbook 长成
  多 Controller；
- rack 部分设置直接失败，变更不自动迁移既有副本；
- kafka_exporter 选中集合变化时必须停掉旧 unit 并删除 stale target；
- 内部 `super.users` 包含 Controller mTLS identity 和 inter-broker Principal；用户对象不
  提供 superuser。

这些要求已经写回最终 `DESIGN.md`。

## 8. 最终收敛状态

两轮之后，没有任何关于公共 API 集合、默认值或范围的分歧。双方共同确认 16 个持久
公共参数：

```text
kafka_cluster
kafka_seq
kafka_role
kafka_cluster_id
kafka_data
kafka_heap_opts
kafka_port
kafka_controller_port
kafka_rack
kafka_parameters
kafka_jmx_exporter_enabled
kafka_jmx_exporter_port
kafka_exporter_port
kafka_security
kafka_users
kafka_topics
```

其中普通三节点 combined 配置实际只需要 `kafka_cluster` 和每节点 `kafka_seq`。

确认删除且不恢复：路径变量、三个 address 变量、`kafka_peer_port`、
`kafka_exporter_kafka_version`、`kafka_exporter_options`。`kafka_clean` 与
`kafka_clean_confirm` 只是危险操作的临时 extra-vars，不属于持久 API。

结论：设计已经收敛，可以按 `DESIGN.md` 的 P0-A → P0-B → P0-C 顺序进入实现，不需要
第三轮全文对抗评审。

## 9. Kafka 4.3 运行验收修正

实现期在真实 Kafka 4.3 集群执行以下 Admin API 操作：

```bash
kafka-configs.sh --bootstrap-server 10.10.10.10:9094 \
  --entity-type brokers --entity-default --alter \
  --add-config default.replication.factor=3
```

Kafka 返回 `InvalidRequestException: Cannot update these configs dynamically:
[default.replication.factor]`。因此第二轮将该 future-only 默认值视为可在线收敛的判断与
Kafka 4.3 实际行为不符。1 combined 扩为 3 Broker 时，重启唯一 Controller 还会同时触发
Controller 多数派和 RF=1 Partition 停机门禁，不能作为安全的自动收敛路径。

最终实现据此将 `default.replication.factor` 与其他复制策略一并冻结在 bootstrap
manifest。该修正不改变 16 项公共 API，也不自动执行 Partition Reassignment；它只撤回
一项经运行事实证明不可实现的验收承诺。
