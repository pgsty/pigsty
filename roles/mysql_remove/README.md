# Role: mysql_remove

> Conservative MySQL member/cluster retirement for Pigsty

| **Playbook**     | `mysql-rm.yml`                                    |
|------------------|---------------------------------------------------|
| **Safeguard**    | `mysql_safeguard=true`                            |
| **Confirmation** | exact `mysql_rm_confirm` instance or cluster name |
| **Data policy**  | preserve all local state                          |

`mysql_remove` is the separately gated scale-in and retirement path for the
native MySQL 8.4 platform. It is intentionally narrower than `pg_remove`:

- one-member HA removal accepts only an ONLINE SECONDARY from a healthy
  three-member cluster and calls AdminAPI with `force: false`;
- a whole-cluster run stops Router, backup timers, MySQL, and exporter in a
  deterministic order and removes VictoriaMetrics file-SD targets;
- every run requires `mysql_safeguard=false` and an exact instance or cluster
  value in `mysql_rm_confirm`;
- datadir, backup, configuration, certificates, packages, local metadata, and
  Router identity are always preserved.
- an initialized datadir must carry Pigsty's exact cluster, instance, and
  topology ownership marker before any service state can change;
- before mysqld stops, a stable root:mysql `0600`
  `/var/lib/mysql/.pigsty-mysql-retired` guard is written so ordinary
  `mysql.yml` cannot accidentally restart preserved state; check mode previews
  the guard without writing it.
- a running mysqld, Router, or exporter outside its native systemd unit fails
  closed; this role never signals an unmanaged process.

Ansible check mode performs the same inventory, service, protected-client, and
Performance Schema topology checks, then reports the exact AdminAPI action. It
does not invoke the lifecycle API. A real single-member run repeats topology
validation inside MySQL Shell and calls `removeInstance()` with `force: false`
and a 60-second synchronization timeout.

A single-member HA run is for same-address node replacement, not a supported
two-member steady state. Replace the machine behind the same advertised service
address, keep that inventory identity, and run the complete three-member
`mysql.yml` scope. The retirement guard remains on the detached host. Reusing
that datadir, changing the member address, removing the guard, or deleting
retained state requires a different, explicitly approved runbook with
recent-backup verification and exact-target confirmation.

Tags follow the normal Pigsty phase shape:

```text
mysql_remove
├── mysql_rm_check
├── mysql_rm_quiesce
├── mysql_rm_member
├── mysql_rm_service
├── mysql_deregister
└── mysql_rm_done
```
