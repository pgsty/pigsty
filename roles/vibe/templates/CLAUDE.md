# Pigsty Vibe Coding Environment

`{{ inventory_hostname }}` | [Docs](https://pigsty.io/docs) | [中文](https://pigsty.cc/docs)

This environment is designed for **vibe coding**—create apps, sites, and visualizations through natural conversation.

What you have:
- **PostgreSQL** — store data, create tables, run queries
- **Nginx** — serve static/dynamic content at http://{{ inventory_hostname }}/
- **Observability** — metrics (VictoriaMetrics), logs (VictoriaLogs), dashboards (Grafana)
- **Python** — `/data/venv/bin/python`, install packages with `uv pip install` (DO NOT TOUCH SYSTEM python! always use the venv)
- **Hugo** — for static sites (available in repo, `yum/apt install hugo`)
- Node.js can be installed with `yum/apt install nodejs`
- Golang can be installed with `yum/apt install golang`

Need more? Pigsty provides Redis, MinIO, etcd, Docker—install on demand.
Main data dir is `/data`—don't touch existing subdirs.

## Services

- PostgreSQL :5432 — `psql postgres://{{ pg_admin_username | default('dbuser_dba') }}:{{ pg_admin_password | default('DBUser.DBA') }}@127.0.0.1/postgres`
- Grafana :3000 — `admin` / `{{ grafana_admin_password | default('pigsty') }}`, http://{{ inventory_hostname }}:3000
- VictoriaMetrics :8428 — http://{{ inventory_hostname }}:8428/vmui
- VictoriaLogs :9428 — http://{{ inventory_hostname }}:9428/select/vmui
- Nginx :80/443 — static root `/www/` → http://{{ inventory_hostname }}/


## Configuration

The environment is created with pigsty, usually single node install.

**The config file `~/pigsty/pigsty.yml` is the single source of truth.** Read it to understand this environment.

```bash
cat ~/pigsty/pigsty.yml                       # view full config
grep -A5 'pg_users:' ~/pigsty/pigsty.yml      # find database users
grep -A5 'pg_databases:' ~/pigsty/pigsty.yml  # find databases
```

Key sections in `pigsty.yml`:
- `all.children.<cluster>.hosts` — node inventory
- `all.children.<cluster>.vars.pg_users` — database users (name, password, roles)
- `all.children.<cluster>.vars.pg_databases` — databases (name, owner, extensions)
- `all.vars` — global defaults

Config docs: https://pigsty.cc/docs/config/


## PostgreSQL

PG {{ pg_version | default(18) }} with [444 extensions](https://pgext.cloud). Cluster: `{{ pg_cluster | default('pg-meta') }}`

```bash
psql 'postgres://{{ pg_admin_username | default('dbuser_dba') }}:{{ pg_admin_password | default('DBUser.DBA') }}@127.0.0.1/postgres'  # admin
sudo -iu postgres psql    # superuser via socket
```

If you are asked to create an app with database, prefer using the existing `meta` database in the current cluster.
or create dedicate new database if necessary. avoid using the `postgres` and `template1` database.
You can use the `public` schema for simple app, and create dedicate schema for complex app.

We don't have pgbouncer, and patroni here, this is a trimed version of single node pigsty

**Admin** ([doc](https://pigsty.cc/docs/pgsql/admin/)):
```bash
pg-backup full                        # backup now (or: incr, diff)
bin/pgsql-user {{ pg_cluster | default('pg-meta') }} <user>   # create user  (define in pigsty.yml first)
bin/pgsql-db   {{ pg_cluster | default('pg-meta') }} <db>     # create db    (define in pigsty.yml first)
```

**Directories**: Data `/pg/data` | Logs `/pg/log` | Backup `/pg/backup`

Backups via pgBackRest, config at `/etc/pgbackrest/`. Use `pg-backup` and `pg-pitr` for backup/recovery.


## Data Layout

```
/data/                # main data dir (DO NOT TOUCH existing subdirs)
├── postgres/         # pg tablespace
├── backups/          # pg backup repo
├── venv/             # python venv
└── ...
/www/                 # nginx static root
{{ vibe_data | default('/fs') }}/                 # vibe workspace (code-server & jupyter root)
~/pigsty/             # pigsty source & config
```

**Rule**: Put your data in `{{ vibe_data | default('/fs') }}/` or `/data/<yourapp>/`. Never modify existing dirs.


## Observability

```bash
curl 'http://127.0.0.1:8428/api/v1/query?query=pg_up'              # query metrics
curl 'http://127.0.0.1:9428/select/logsql/query?query=*'           # query logs
curl -X POST 'http://127.0.0.1:8428/opentelemetry/v1/metrics' -d   # push metrics
curl -X POST 'http://127.0.0.1:9428/insert/opentelemetry/v1/logs' -d  # push logs
```

Grafana dashboards: PGSQL, NODE, INFRA at http://{{ inventory_hostname }}:3000


## Web Publishing

Nginx serves `/www/` at http://{{ inventory_hostname }}/.

- HTML: write to `/www/mypage.html` → access at `/mypage.html`
- Static site: use `hugo` (in repo), build to `/www/mysite/`
- Dynamic app: run on a port, access directly or proxy via Nginx

It can handle domain names, https certs, make good use of it: https://pigsty.cc/docs/infra/admin/



## Reference

- [PGSQL Admin](https://pigsty.cc/docs/pgsql/admin/) | [User](https://pigsty.cc/docs/pgsql/user/) | [Database](https://pigsty.cc/docs/pgsql/db/) | [Backup](https://pigsty.cc/docs/pgsql/backup/)
- [Config](https://pigsty.cc/docs/config/) | [Playbook](https://pigsty.cc/docs/pgsql/playbook/) | [Extensions](https://pgext.cloud/list)
- [CLI Tools](https://pigsty.cc/docs/pgsql/admin/#pigsty-cli-tools): `bin/pgsql-*`, `bin/node-*`, `bin/redis-*`
