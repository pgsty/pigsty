# Pigsty Kafka 最终设计：精简 API 与生产级约定

> 状态：两轮对抗性评审后收敛的最终设计，不代表已实现
>
> 日期：2026-07-16
>
> 适用基线：Pigsty v4.4.0、Apache Kafka 4.3.x、KRaft only

## 1. 目标

Pigsty Kafka 模块的目标不是复制云厂商的全部产品面，而是在保持 Pigsty
声明式、低心智负担体验的前提下，提供一个可重复、可审计、可监控、可安全维护的
Kafka 生产部署基线。

设计必须同时满足两条约束：

1. Kafka 语义必须正确，不能用兼容映射掩盖错误抽象。
2. 每一个公共参数都有复杂度成本；能够从 inventory、包契约或其他参数推导的值，
   不进入公共 API。

本设计采用以下 API 准入测试。一个候选参数只有同时满足这些条件才允许公开：

- 用户确实存在反复表达该意图的需要；
- 该值无法可靠地从 inventory、拓扑或包内容推导；
- 它具有稳定、面向用户的语义，而不是当前实现路径；
- 不公开它会阻止一个明确的生产场景；
- 它不能合理地由唯一的高级逃生舱 `kafka_parameters` 表达。

## 2. 明确边界

核心 role 负责：

- KRaft Broker、Controller 与 combined 节点部署；
- 软件包、目录、systemd、配置和幂等存储格式化；
- 节点 JVM 监控、Kafka 协议监控、日志与 VictoriaMetrics 注册；
- 安全滚动、拓扑校验和生产护栏；
- 后续的 TLS、SCRAM、ACL、Quota、Topic 和用户声明式管理。

核心 role 暂不负责：

- Cruise Control、MirrorMaker 2、Connect、Schema Registry、Web UI；
- Tiered Storage；
- IaaS 自动换机和按负载自动扩缩容；
- 客户端 `acks`、幂等、重试等 SDK 策略；
- 把单集群复制伪装成备份或跨地域零 RPO。

这些能力可以作为后续独立模块或显式跨集群关系加入，不能污染 Kafka 核心 API。

## 3. 最终角色语义

`kafka_role` 只接受三个值：

| `kafka_role` | Kafka `process.roles` | 语义 |
|---|---|---|
| `combined` | `broker,controller` | Broker 与 Controller 合设，默认值 |
| `broker` | `broker` | 纯 Broker |
| `controller` | `controller` | 纯 Controller |

最终默认值必须是真正存在于 role defaults 中的：

```yaml
kafka_role: combined
```

决策：

- 删除 `controller-only`，不提供 alias、deprecated warning 或迁移分支；
- 旧的 `controller` 不再表示 combined；
- 集群中没有任何节点显式设置角色时，所有节点一致视为 `combined`；
- 只要集群中任一节点显式设置角色，所有节点都必须显式设置，缺失即失败；
- `kafka_process_roles`、`kafka_has_broker`、`kafka_has_controller` 是内部事实，
  不是公共参数；
- Controller quorum 只包含 `combined` 和 `controller`；
- Broker 数量只计算 `combined` 和 `broker`；
- `kafka_seq` 是全局唯一的 KRaft `node.id`。

推荐拓扑是约定，不增加 profile 参数：

- 开发：1 个 combined；
- 常规生产：3 个 combined；
- 关键或较大集群：3 个 controller + N 个 broker；
- 5 个 controller 只用于需要容忍两个 Controller 故障的环境；
- 至少存在一个 Controller 和一个 Broker；偶数 Controller quorum 给出明确警告。

### 3.1 KRaft quorum 约定

Kafka 4.3 新集群直接使用 dynamic quorum，不再创建 static quorum：

```properties
controller.quorum.bootstrap.servers=<all-controller-inventory-addresses>
```

- 不渲染已被 KRaft version 1 弃用的 `controller.quorum.voters`；
- 所有 Broker 和 Controller 都渲染 `controller.quorum.bootstrap.servers`；
- 每个节点 format 时必须显式使用 `--standalone`、`--initial-controllers`、
  `--no-initial-controllers` 三者之一，禁止静默回落到 static quorum；
- initial Controller node/directory identity 在 bootstrap 时生成并冻结；
- 新 Broker 使用 `kafka-storage.sh format --no-initial-controllers`；
- 新 Controller 出现在 inventory 中不等于自动加入 quorum；必须先 format、启动、追平，
  再执行显式 `add-controller`；
- Controller 删除同样是显式成员变更动作；
- 单 combined 开发集群在 v1 不能仅通过重跑普通 playbook 扩成多 Controller 集群；扩展
  Controller 必须走显式成员变更流程；
- 不增加 `kafka_quorum_mode`、voter list 或 bootstrap server 公共参数。

## 4. 最终监听器模型

核心模块只提供两个语义监听器：

- `BROKER`：客户端访问与 Broker 间通信共用；
- `CONTROLLER`：KRaft 控制面。

不在核心 API 中预先增加 `CLIENT`、`INTERNAL`、`EXTERNAL` 三套监听器，也不公开
listener map。未来只有出现经过验证、无法用该模型部署的真实需求时，再增加结构化高级
listener API。

listener 名称表达用途，不使用 `PLAINTEXT`、`SSL` 等协议名。安全模式在新集群 bootstrap
时确定；普通配置收敛不允许直接把既有 listener 从 PLAINTEXT 切换到 SASL_SSL。

### 4.1 combined

```properties
process.roles=broker,controller
listeners=BROKER://0.0.0.0:9092,CONTROLLER://0.0.0.0:9095
advertised.listeners=BROKER://<inventory_hostname>:9092
inter.broker.listener.name=BROKER
controller.listener.names=CONTROLLER
```

### 4.2 broker

```properties
process.roles=broker
listeners=BROKER://0.0.0.0:9092
advertised.listeners=BROKER://<inventory_hostname>:9092
inter.broker.listener.name=BROKER
controller.listener.names=CONTROLLER
```

### 4.3 controller

```properties
process.roles=controller
listeners=CONTROLLER://0.0.0.0:9095
controller.listener.names=CONTROLLER
```

约定：

- bind address 固定为 `0.0.0.0`；
- advertised broker address 固定为 `inventory_hostname`；
- controller quorum address 固定为 `inventory_hostname`；
- Controller listener 永远不进入 `advertised.listeners`；
- 纯 Controller 不配置 `advertised.listeners`；
- 不提供 `kafka_bind_address`、`kafka_advertise_address`、
  `kafka_controller_address`；
- 不提供独立 INTERNAL port 或 EXTERNAL listener；
- `kafka_peer_port` 直接更名为 `kafka_controller_port`，不保留兼容变量。

这意味着本模块明确以 Pigsty inventory 地址作为 Kafka 稳定节点地址，并要求客户端可以
直接路由到该地址。NAT、公网暴露、同一 Broker 多客户端网络等场景不进入 v1 核心承诺；
未来只有经过真实需求和集成测试验证后，才增加结构化高级 listener API。

## 5. 最终公共 API

### 5.1 核心部署 API

| 参数 | 默认值 | 决策理由 |
|---|---:|---|
| `kafka_cluster` | 必填 | 集群身份，无法从任意 Ansible group 名安全推导 |
| `kafka_seq` | 必填 | KRaft `node.id`，需要用户明确分配且集群内唯一 |
| `kafka_role` | `combined` | 唯一拓扑选择 |
| `kafka_cluster_id` | bootstrap 时随机生成 | 仅接管或恢复非 Pigsty 集群时显式覆盖 |
| `kafka_data` | `/data/kafka` | 用户必须能选择真实数据盘挂载根目录 |
| `kafka_heap_opts` | `-Xms1G -Xmx1G` | 与机器规格和负载相关，无法安全自动推导 |
| `kafka_port` | `9092` | Broker/client service port |
| `kafka_controller_port` | `9095` | Controller port；9093 与 Pigsty AlertManager 冲突 |
| `kafka_rack` | 未设置 | 多 Broker、多故障域时表达 `broker.rack` |
| `kafka_parameters` | `{}` | 唯一 Kafka server 参数逃生舱 |

新集群的 Cluster ID、initial Controller directory IDs、安全模式和初始复制策略写入
admin 节点上的 cluster bootstrap manifest。Cluster ID 不再由集群名 hash 得出，避免同名
环境和同名重建共享身份。`kafka_cluster_id` 属于高级恢复接口，不出现在普通样例中，也
不要求用户日常设置。

`kafka_rack` 只在 broker-capable 节点渲染。三节点 RF=3 集群无需填写；Broker 数量大于
默认 RF 且跨多个故障域的生产集群必须填写并验证副本放置。Pigsty 约定 rack 要么在全部
broker-capable 节点上设置，要么全部不设置；部分设置直接失败，避免产生虚假的故障域
保障。rack 是 read-only Broker 配置，变更会触发滚动，但不会迁移既有副本。

`kafka_parameters` 不允许覆盖 role 拥有的身份、拓扑、监听器、安全与存储键，包括：

```text
process.roles
node.id
controller.quorum.*
listeners
advertised.listeners
listener.security.protocol.map
inter.broker.listener.name
controller.listener.names
log.dirs
metadata.log.dir
min.insync.replicas
```

### 5.2 监控 API

| 参数 | 默认值 | 决策理由 |
|---|---:|---|
| `kafka_jmx_exporter_enabled` | `true` | 允许极简环境明确关闭 JVM 监控 |
| `kafka_jmx_exporter_port` | `9404` | 端口冲突是合法部署需求 |
| `kafka_exporter_port` | `9308` | 端口冲突是合法部署需求 |

不增加 `kafka_exporter_enabled`。`kafka-stack` 已经是 Kafka、kafka_exporter、
jmx-exporter 的完整生产安装单元，协议 Exporter 是标准能力。

### 5.3 后续生产安全与资源 API

生产安全不拆成 `tls_enabled`、`sasl_enabled`、`acl_enabled`、`quota_enabled` 等互相
组合的布尔变量。只保留一个安全级别：

```yaml
kafka_security: plaintext        # plaintext | scram
```

| 参数 | 默认值 | 决策理由 |
|---|---:|---|
| `kafka_security` | `plaintext` | 单一安全策略选择，避免多布尔组合 |
| `kafka_users` | `[]` | Principal、Credential、ACL、Quota 的必要领域对象 |
| `kafka_topics` | `[]` | 生产关闭自动建 Topic 后的必要资源对象 |

- `plaintext`：开发、测试和受信网络基线；
- `scram`：生产安全组合，自动包含 TLS、SCRAM-SHA-512、StandardAuthorizer 与
  deny-by-default；
- Controller 控制面使用 TLS 双向认证；
- Broker/client listener 使用 SASL_SSL；
- Broker 间凭据、证书路径、listener security map、SCRAM mechanism 和 JAAS 文件是
  role 内部实现，不增加参数；
- 安全模式写入 bootstrap manifest。已初始化集群通过普通 playbook 改变安全模式时
  fail-fast；在线安全迁移是未来显式 admin 状态机，不扩展稳态 listener API；
- role 内部拥有 inter-broker、admin、monitor 三类 Principal；
- inter-broker/admin 初始 SCRAM credential 在首个 Broker 启动前写入 metadata；
- monitor Principal 在 deny-by-default 对外生效前获得最小 Describe ACL。

资源生命周期只增加两个必要领域对象：

```yaml
kafka_users: []
kafka_topics: []
```

`kafka_users` 中一个对象同时表达 Principal、密码、ACL 和可选 Quota，不再新增平行的
`kafka_acls`、`kafka_quotas`：

```yaml
kafka_users:
  - name: order-service
    password: "{{ vault_kafka_order_password }}"
    acls:
      - resource: topic
        name: order.
        pattern: prefixed
        operations: [Read, Write, Describe]
      - resource: group
        name: order.
        pattern: prefixed
        operations: [Read]
      - resource: transactional_id
        name: order.
        pattern: prefixed
        operations: [Write, Describe]
    quota:
      producer_byte_rate: 10485760
      consumer_byte_rate: 20971520
```

`kafka_topics` 表达无法由 Broker 静态配置替代的 Topic 生命周期：

```yaml
kafka_topics:
  - name: order.events
    partitions: 12
    replication_factor: 3
    config:
      min.insync.replicas: 2
      cleanup.policy: delete
```

资源语义：

- ACL resource 支持 `topic`、`group`、`transactional_id`、`cluster`；
- Pigsty admin 是用户可见的唯一默认 superuser，用户对象不提供 `superuser`；内部
  `super.users` 还包含 Controller mTLS identity 与 inter-broker Principal；
- Topic create 幂等，partition 只允许增加；
- replication factor 的普通字段变更在 v1 拒绝，并输出显式 reassignment 动作；
- 只收敛 `config` 中明确声明的键；
- 从 `kafka_topics` 删除条目不会删除 Topic；删除必须使用独立危险操作。

不把客户端 `acks`、幂等、重试、批量、压缩等参数放进 Broker role。

## 6. 从公共 API 删除或降级为内部约定

以下现有变量删除，不提供兼容别名：

```yaml
kafka_home
kafka_config
kafka_log4j_config
kafka_data_dir
kafka_metadata_dir
kafka_peer_port
kafka_bind_address
kafka_advertise_address
kafka_controller_address
kafka_exporter_kafka_version
kafka_exporter_options
```

内部固定约定：

- Kafka home：`/opt/kafka`；
- server config：`/etc/kafka/server.properties`；
- log4j config：`/etc/kafka/log4j2.yaml`；
- JMX config：`/etc/kafka/jmx_exporter.yml`；
- JMX Java agent：`/usr/share/java/jmx_prometheus_javaagent.jar`；
- broker data：`${kafka_data}/data`；
- metadata：`${kafka_data}/metadata`；
- bind address：`0.0.0.0`；
- advertised/quorum address：`inventory_hostname`；
- kafka_exporter Kafka protocol compatibility：由安装包版本内部决定；
- kafka_exporter 启动参数：由 role 和安全模式内部生成。

`kafka_clean` 与 `kafka_clean_confirm` 是危险运维动作的临时 extra-vars，不是持久集群
配置。它们不应出现在默认 API 表中，但清理任务继续要求 `never` tag、显式布尔值和精确
集群名三重确认。

## 7. 自动派生的生产约定

role 在首次 bootstrap 时从初始 broker 数量推导基础复制策略，不再要求用户为单机、双机
和三节点样例分别覆盖：

```text
replication_factor = min(3, broker_count)
min_insync_replicas = max(1, replication_factor - 1)
```

该约定用于：

- `default.replication.factor`；
- `offsets.topic.replication.factor`；
- `transaction.state.log.replication.factor`；
- `transaction.state.log.min.isr`；
- share coordinator 内部 Topic 参数。

所有派生复制值进入 bootstrap manifest，此后不再随 inventory broker count 自动变化，
包括未来 Topic 默认 RF、内部 Topic RF、`transaction.state.log.min.isr` 和 cluster-level
`min.insync.replicas`。扩容后：

- role 读取内部 Topic 的实际 RF/minISR；
- 与初始策略不一致时报告 drift；
- 不自动提高 minISR，也不声称既有内部 Topic 已获得更高 RF；
- RF 提升通过显式 reassignment/admin 动作完成。

Kafka 4.3 将 `default.replication.factor` 作为静态 Broker 配置，Admin API 会以
`Cannot update these configs dynamically` 拒绝在线修改。它虽然只影响未来创建的 Topic，
但从 1 Broker 扩到 3 Broker 时仍不能靠角色安全收敛：旧 combined 节点既是唯一
Controller，又承载 RF=1 Partition，严格停机门禁会正确拒绝重启。角色因此冻结初始默认
RF；需要提升时，必须显式完成既有 Partition Reassignment、Controller 高可用或维护窗口
规划，并在可安全滚动后更新静态配置。

配置层级内部区分：

1. 静态 node/server 配置，必要时触发滚动；
2. role-owned dynamic cluster 配置；
3. Topic 配置。

Kafka 4.3 ELR 集群的默认 `min.insync.replicas` 在 cluster level 收敛。role 只有值实际变化
时才更新，避免无意义更新清空 ELR 状态。用户不能通过 `kafka_parameters` 把它写回
broker-level；当前不增加 `kafka_cluster_parameters` 公共 map。

生产安全模式关闭自动建 Topic；Topic 由 `kafka_topics` 或显式管理命令创建。开发模式可以
保留 Kafka 默认的自动建 Topic 体验。

role 只为 broker-capable 节点渲染 Broker 参数。Controller 所需的 KRaft、监听器、安全和
metadata 参数由 role 自己生成，不增加 `kafka_controller_parameters`。

## 8. 监控与服务约定

### 8.1 JMX Exporter

- enabled 时每个 Kafka JVM 都注入 JMX Exporter Java agent；
- enabled 时 combined、broker、controller 三种角色都注册 `job=kafka`；
- production monitoring baseline 要求 enabled；关闭只影响可观测性，不改变健康门禁实现；
- 配置文件、Java agent path 和 bind address 固定，不公开；
- JMX 规则采用有界 allow-list，不导出 client-id、partition 等无界标签；
- Dashboard 的节点/JVM/请求路径/KRaft 指标只使用 JMX 数据。

### 8.2 kafka_exporter

- 只在按 `kafka_seq` 排序后的前两个 broker-capable 节点运行和注册；
- 单 Broker 集群只运行一个；
- Controller 不运行，也不保留 stale target；
- Exporter 选择集合变化时，原先选中但现已落选的节点必须停止 unit 并删除 stale target；
- 它暴露的是集群级 Topic、Partition、Consumer Group 与 Lag 数据，不能当作节点指标；
- Dashboard 与告警必须按 cluster 使用 `max` 或去除 exporter replica label 的等价聚合，
  不能对多个 exporter replica 求和；
- Exporter 的 Kafka 版本、TLS、SCRAM 参数由 role 自动生成。

这是一项有意识的取舍：采集成本固定为最多两份，同时避免单 Exporter 进程成为监控单点；
不增加 exporter placement、replica count、enabled 或通用 options 参数。

## 9. 用户配置样例

### 9.1 默认三节点 combined

```yaml
kf-main:
  hosts:
    10.10.10.11: { kafka_seq: 1 }
    10.10.10.12: { kafka_seq: 2 }
    10.10.10.13: { kafka_seq: 3 }
  vars:
    kafka_cluster: kf-main
```

### 9.2 Controller/Broker 分离

```yaml
kf-main:
  hosts:
    10.10.10.11: { kafka_seq: 1, kafka_role: controller }
    10.10.10.12: { kafka_seq: 2, kafka_role: controller }
    10.10.10.13: { kafka_seq: 3, kafka_role: controller }
    10.10.10.21: { kafka_seq: 4, kafka_role: broker }
    10.10.10.22: { kafka_seq: 5, kafka_role: broker }
    10.10.10.23: { kafka_seq: 6, kafka_role: broker }
  vars:
    kafka_cluster: kf-main
```

正常配置不出现 role、port、path、address、listener、quorum 或 exporter 细节。

## 10. 生命周期与安全护栏

API 简单不能以牺牲内部正确性为代价。实现必须具备：

- 一次生命周期操作必须通过 `-l` 明确限制单一 Kafka 集群；
- 对外用 bootstrap、cold-start/repair、rolling 描述生命周期；实现只使用一个判定谓词：
  quorum 当前健康则进入严格 rolling，否则进入统一 converge 路径；
- converge 覆盖首次 bootstrap、中断后续建、全集群 cold-start 和修复：先 format/启动足够
  的 Controller 形成 dynamic quorum，统一验收后启动 Broker；
- rolling 每次只处理一个节点；重启前后检查 Controller quorum、Offline Partitions、
  Under Min ISR、ISR catch-up，并从检查中排除当前目标节点；
- rolling 任一健康门禁失败立即终止后续节点；
- 健康门禁一律通过 role-owned admin 通道的 Kafka CLI/metadata API 执行，只有一套实现；
  JMX 只用于监控告警，关闭时 preflight 明确警告可观测性降级；
- 已格式化存储只验证 `cluster.id` 与 `node.id`，绝不自动重格式化；
- converge/repair 发现已格式化 Controller 的 directory ID 与 quorum 记录不一致时
  fail-closed，并指向显式 remove-controller/add-controller 流程；
- bootstrap manifest 与现场 Cluster ID、quorum mode、安全模式、初始 Controller identity
  不一致时 fail-closed；
- 配置变化不允许无条件同时重启多个节点；
- 动态配置优先在线修改，静态配置才触发滚动；
- 升级与元数据 feature level 终结是显式运维动作；
- 加节点不等于自动完成分区重分配，退役节点必须有独立 drain/reassign 流程。

这些是实现与 playbook 状态机，不增加 `safe_mode`、`rolling_enabled`、
`health_gate_enabled` 等参数；生产安全行为应是唯一行为。

### 10.1 Bootstrap manifest 权威边界

manifest 固定存放在 `files/kafka/<kafka_cluster>/`，只记录无法从 inventory 推导的
bootstrap 事实：

- Cluster ID；
- initial Controller 的 node ID 与 directory ID；
- bootstrap 安全模式；
- 影响既有对象行为的初始复制策略。

它不保存 Kafka 版本、feature level、Topic/User/ACL 清单或其他可变运行状态。权威规则：

1. 活集群永远是运行事实权威；manifest 只用于首次 format 和交叉校验；
2. manifest 丢失但集群健在时，从 meta.properties、metadata API 和现场配置重建，输出
   明确警告，绝不 reformat；
3. manifest 健在但所有 Kafka 数据盘为空时 fail-closed，防止用旧身份复活已消失的集群；
   全新 bootstrap 必须先通过受保护的显式清理动作处置旧 manifest；
4. manifest 与健在集群冲突时以现场为事实，但普通 playbook 不自动改写任何一方，而是
   fail-closed，要求管理员先判定这是 stale manifest、错误 inventory 还是错误目标集群。

## 11. 实施顺序

### P0-A：立即修正 Beta API

1. `kafka_role` 收敛为 combined/broker/controller，默认 combined；
2. 删除 controller-only 及全部兼容逻辑；
3. `kafka_peer_port` 改为 `kafka_controller_port`；
4. 删除所有 address/path/exporter implementation 参数，增加必要的 `kafka_rack`；
5. listener 改为 BROKER/CONTROLLER，并修正 advertised listener；
6. 新集群改为 dynamic quorum，随机生成 Cluster ID 和 Controller directory IDs；
7. 引入 bootstrap manifest，冻结安全模式与初始复制策略；
8. 修正服务条件、监控标签、样例与文档；
9. 建立三种合法角色、全默认/全显式规则和渲染测试；不维护旧 API 墓碑。

### P0-B：监控与滚动安全

1. 验证三种角色 JMX 指标；
2. kafka_exporter 收敛为最多两个派生副本并校正 Dashboard/告警聚合；
3. 实现 converge/rolling 双路径判定、生命周期状态机与健康门禁；
4. 强制单集群 limit，消除跨集群 serial 耦合；
5. 完成 1 combined、3 combined、3 controller + 3 broker 集成测试。

### P0-C：安全与资源控制面

1. 实现 `kafka_security: scram` 的完整 TLS/SCRAM/ACL bootstrap；
2. 实现内部 inter-broker/admin/monitor Principal 及正确启用顺序；
3. 实现 `kafka_users` 幂等创建、变更、ACL 与 Quota 收敛；
4. 实现 `kafka_topics` 幂等创建与安全、单调配置变更；
5. 建立凭据与证书轮换流程；
6. 增加 deny-by-default 启用顺序和失败回滚测试。

## 12. 验收标准

静态与渲染验收：

- 未设置 `kafka_role` 渲染为 `process.roles=broker,controller`；
- `combined`、`broker`、`controller` 分别精确映射到原生角色；
- 同集群 role 要么全部缺省 combined，要么全部显式；
- broker-capable 节点的 `kafka_rack` 要么全有要么全无；
- Controller 配置没有 BROKER listener、advertised listener 或 kafka_exporter；
- Broker 配置不绑定 CONTROLLER listener；
- combined 只 advertise BROKER listener；
- 所有节点使用 `controller.quorum.bootstrap.servers`，不渲染静态 voters；
- node.id 集群内唯一；
- role-owned 参数无法由 `kafka_parameters` 覆盖。

运行验收：

- 1 combined 可以完成 format、启动、重跑与指标注册；
- 3 combined 形成 dynamic quorum，可创建 RF=3/minISR=2 Topic，并承受一个 Broker 停止；
- 3 controller + 3 broker 可完成 dynamic quorum 选举和 Broker 重启；
- 每类节点 format 均显式进入 dynamic quorum，`kraft.version` 不回落为 static；
- bootstrap manifest 使用随机 Cluster ID，且同名重建不会复用旧身份；
- 从 1 Broker 扩到 3 Broker 不会自动把既有 RF=1 内部 Topic 的 minISR 提高到 2；
- 从 1 Broker 扩到 3 Broker 后，既有与新建 Topic 均保持初建默认 RF=1，角色不以危险
  重启伪装复制策略升级；
- JMX 覆盖每个 JVM；kafka_exporter 目标数不超过两个且不会造成 Dashboard/告警倍增；
- 非选中的 broker-capable 节点没有运行中的 kafka_exporter unit 或残留 target；
- bootstrap、全集群 cold-start 和健康集群 rolling 都能通过各自状态路径；
- scram bootstrap 完成后 monitor Principal 可以立即完成协议指标抓取；
- 单节点滚动期间不会出现 Offline Partition 或低于 minISR 后继续滚动；
- 已格式化节点 cluster/node identity 不匹配时安全失败；
- clean 任务没有完整三重确认时拒绝执行。

## 13. 两轮对抗性评审结论

Claude Code Fable 5 与 Codex 经过两轮评审后，对公共 API、默认值和范围已经收敛：

- 新集群从第一版直接使用 dynamic quorum；
- `kafka_role` 只有 combined/broker/controller，默认 combined；
- 删除全部 address 参数，包括 `kafka_advertise_address`，不允许 raw listener override；
- 公共 placement 只增加确有生产必要性的 `kafka_rack`；
- Cluster ID 随机生成，bootstrap-only 事实进入最小 manifest；
- 安全模式是 v1 产品契约上的 bootstrap-only 属性，而不是错误宣称为 Kafka 永久限制；
- JMX enabled/port 保留，但健康门禁与 JMX 解耦，只维护 admin API/CLI 一条路径；
- kafka_exporter 最多两个派生副本，不恢复通用 options；
- RF/minISR 与 future-only 的 `default.replication.factor` 均冻结为 bootstrap 策略；
- Topic、User、ACL、Quota 采用最小领域对象，不增加平行列表或功能开关。

完整的第一轮意见、Codex 逐项回应、第二轮撤回与最终裁决记录在同目录
`REVIEW.md`。当前没有需要扩大或改变公共 API 的未决 blocker，可以进入 P0-A 实现。
