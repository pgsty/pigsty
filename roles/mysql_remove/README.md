# Role: mysql_remove

> Remove a MySQL member or cluster from Pigsty

| **Playbook**  | `mysql-rm.yml`                                    |
|---------------|---------------------------------------------------|
| **Safeguard** | `mysql_safeguard=true`                            |
| **Scope**     | one member, or the complete cluster               |

`mysql_remove` follows the other Pigsty removal roles:

| Variable          | Default       | Description                                  |
|-------------------|---------------|----------------------------------------------|
| `mysql_safeguard` | `true`        | abort unless explicitly set to `false`       |
| `mysql_rm_data`   | `true`        | remove data, config, secrets, router state   |
| `mysql_rm_pkg`    | `false`       | uninstall MySQL packages                     |
| `mysql_data`      | `/data/mysql` | data directory; must match the `mysql` role  |

The safeguard defaults to `true` because this is a database. The playbook also
requires an explicit `-l` limit.

```bash
./mysql-rm.yml -l my-test -e mysql_safeguard=false                         # remove the cluster
./mysql-rm.yml -l my-test -e mysql_safeguard=false -e mysql_rm_data=false  # stop it, keep everything
./mysql-rm.yml -l 10.10.10.13 -e mysql_safeguard=false                     # remove one member
```

- **Complete cluster**: stops Router, backup units, exporter, and mysqld, then
  removes the data directory, Pigsty config and secrets, Router state, and the
  monitoring targets. With `mysql_rm_data=false` everything stays on disk and
  `mysql.yml` brings the stopped cluster back.
- **One member**: the member first leaves the InnoDB Cluster through a
  surviving member. A PRIMARY hands over and an ONLINE member syncs and
  leaves; a member in any other state must be recovered or replaced at the
  same address through `mysql.yml`. Pigsty runs MySQL with one or three
  members, so run `mysql.yml` next: it clones the removed member back on the
  same or a replaced machine. A dead machine needs no removal at all; see the
  `mysql` role. Preserving data while detaching one member is rejected because
  that state cannot be reconciled as either a retained cluster or a fresh clone.
- **Backups** under `mysql_backup_dir` are never removed.

Tags:

```text
mysql_remove
├── mysql_safeguard   assert identity and honor the safeguard
├── mysql_leave       detach a single member through a survivor
├── mysql_deregister  remove VictoriaMetrics targets
├── mysql             stop services
├── mysql_data        remove data, config, secrets, and router state
└── mysql_pkg         uninstall packages
```
