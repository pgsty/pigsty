# Role: kafka_remove

> Remove Kafka Cluster & Instances from Node

| **Module**        | [KAFKA](https://pigsty.io/docs/kafka)       |
|-------------------|---------------------------------------------|
| **Docs**          | https://pigsty.io/docs/kafka/admin          |
| **Related Roles** | [`kafka`](../kafka)                         |


## Overview

The `kafka_remove` role removes a Kafka node from a cluster, the mirror of the
`kafka` role. It is invoked by the `kafka-rm.yml` playbook and never by `kafka.yml`,
so cluster expansion (`kafka.yml`) and shrink/teardown (`kafka-rm.yml`) stay on
separate, explicit paths.

Steps:

- Honor the `kafka_safeguard` protection (abort if enabled)
- Deregister `kafka` / `kafka_exporter` targets from all infra nodes
- Stop and disable the `kafka` and `kafka_exporter` services
- Remove exporter config, systemd environment/units, and role-owned helper scripts
- Remove the data directory and `/etc/kafka` recovery state when `kafka_rm_data` is set
- Uninstall the kafka-stack packages when `kafka_rm_pkg` is set


## Parameters

| Name              | Default       | Description                                              |
|-------------------|---------------|----------------------------------------------------------|
| `kafka_safeguard` | `false`       | prevent purging a running kafka cluster when `true`      |
| `kafka_rm_data`   | `true`        | remove data dir and `/etc/kafka` recovery state          |
| `kafka_rm_pkg`    | `false`       | uninstall kafka & kafka-exporter packages during removal |
| `kafka_data`      | `/data/kafka` | kafka data directory (must match the `kafka` role)       |


## Tags

| Tag                | Description                                 |
|--------------------|---------------------------------------------|
| `kafka_safeguard`  | evaluate the safeguard gate                 |
| `kafka_deregister` | remove monitoring targets from infra        |
| `kafka`            | stop kafka & kafka_exporter services        |
| `kafka_config`     | remove service integration and helper files |
| `kafka_data`       | remove data dir and `/etc/kafka` state      |
| `kafka_pkg`        | uninstall kafka-stack packages              |


## Example

```bash
./kafka-rm.yml -l kf-main                        # remove cluster kf-main (keep packages)
./kafka-rm.yml -l kf-main -e kafka_rm_data=false # keep data and recovery state; remove service integration
./kafka-rm.yml -l kf-main -e kafka_rm_pkg=true   # also uninstall the kafka-stack packages
```
