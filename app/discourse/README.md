# Discourse

Discourse with external Pigsty PostgreSQL and a single embedded Redis instance.
The official classic `discourse_docker` Launcher builds the application image;
Docker Compose manages its runtime. This uses Pigsty's normal
`app.yml` → application directory → `.env` → `make` workflow. Its `dest` is
`/data/app/discourse`, so configuration and persistent files move together.

| Item | Default |
|---|---|
| Forum domain | `ask.pigsty` |
| PostgreSQL | `10.10.10.10:5432`, database/user `discourse` |
| Redis | One instance inside the application container, `127.0.0.1:6379` |
| Public HTTP/HTTPS | Pigsty Nginx, `80` / `443` |
| Nginx upstream | `unix:/data/app/discourse/shared/nginx.http.sock` |
| Application files | `/data/app/discourse` |
| Management files | `/data/app/discourse`, alongside persistent files |

No PostgreSQL container is created. Redis and HTTP ports are not published by
Docker. The Unix socket avoids a collision with Pigsty Nginx on port 80. The
Redis instance binds only to container loopback; it is not shared with other
applications or Pigsty's native Redis services. Build and runtime use the same
default Docker bridge, so database reachability and source addresses agree.

## Install

On a **fresh host**, use [the inventory template](../../conf/app/discourse.yml):

```bash
cd ~/pigsty
./configure -c app/discourse
vi pigsty.yml                       # change passwords, domain and SMTP
./deploy.yml                       # provision Pigsty and PostgreSQL
./docker.yml                       # install Docker and Compose
./app.yml -l discourse              # build and launch Discourse
```

On an **existing Pigsty deployment**, merge the `discourse` app definition,
`discourse` user/database and portal into the current inventory. Keep its
existing cluster name, hosts, users, databases and other portals. Do not run
`configure` over a live inventory or initialize the running cluster again.
After reviewing the merged configuration, create only the new database/user,
install `pgvector` if needed, apply the HBA and new portal, then launch the app.

The database needs PostgreSQL **18**, UTF8, and `hstore`, `pg_trgm`, `unaccent`,
`vector`. Pigsty creates these extensions as the DBA; the `discourse` owner
performs application migrations without SUPERUSER, CREATEDB or shared admin
roles. `files/discourse.sql` overrides the shared default ACLs for this owner.
Use direct PostgreSQL, not PgBouncer transaction mode: Discourse uses advisory
locks. For HA, substitute a primary-only direct-PostgreSQL endpoint and set the
backup endpoint to the same writer. A fixed node's 5432 does not follow failover.

The default Docker HBA rule permits only this database/user from Docker bridge
addresses. Existing firewalls must allow the application's bridge to reach the
configured database. This template does not change firewall rules or unrelated
demo routes.

Configure SMTP and the administrator's email before launching. The example
SMTP host deliberately fails the build until replaced. For an isolated test
only, set `DISCOURSE_SKIP_EMAIL_SETUP=1`; that does not provide working email.
For public deployment use a real domain, a valid TLS certificate and
`DISCOURSE_FORCE_HTTPS=true`. Resolve `ask.pigsty` to the Nginx host for local
testing; it is not a public certificate name.

## Image build and operation

```bash
cd /data/app/discourse
make config                        # inspect the Launcher definition, secrets redacted
make up                            # first build, then start and wait for HTTP health
make view
make health
make log
make stop
make start                         # start the unchanged, previously built image
make rebuild                       # stop, rebuild/migrate, then start
make clean                         # remove the container, preserve files and PostgreSQL
```

The defaults pin both `DISCOURSE_DOCKER_REF` and `DISCOURSE_VERSION` to exact
commits verified together. The Launcher selects the base image and its Ruby
version; a floating application branch can outgrow that runtime. Update and
verify both refs together, including the required PostgreSQL major version.
`make up` reuses the image when its local build receipt and resolved configuration
match; `make rebuild` rebuilds the configured version.

The generated `launcher/containers/discourse.yml` is JSON, which is valid YAML,
and has mode 0600. It uses Redis, Web, rate-limit and socket templates, with no
PostgreSQL/SSL/Let's Encrypt templates. The application image is built locally;
the experimental prebuilt `discourse/discourse` image is not used.

Builds stop the old app **before** bootstrap, because bootstrap also starts
Redis on the shared data directory. Never bootstrap another instance against
an active `shared/redis_data`, start two copies of this app or use Launcher V2's
automatic external-database rebuild with this embedded-Redis layout. A failed
build leaves the old app stopped; inspect the error and resolve it before
starting an image against a potentially migrated schema.

Run the build on Linux with Docker, Compose v2.20+, Git and Python 3. The
Launcher supports x86-64; upstream describes ARM64 support as experimental.
The first build needs network access for Docker Hub, GitHub, gems and frontend
dependencies, plus temporary CPU/RAM/disk headroom. Begin with two Web workers,
one Sidekiq process, five job threads and an eight-connection pool per process.
An 8 GiB host can start a small forum alongside Pigsty; keep room for monitoring
and builds, and use 16 GiB for more maintenance headroom.

## Persistent data and backups

```text
/data/app/discourse/
├── launcher/                      # pinned upstream source and private app definition
├── .build.json                    # config fingerprint, image ID and exact source commit
└── shared/
    ├── uploads/                   # original files, attachments and derived images
    ├── redis_data/                # RDB / complete AOF file set
    ├── backups/default/           # Discourse application archives
    ├── log/                       # Rails, Sidekiq, Redis and system logs
    ├── state/                     # logrotate/anacron state
    └── tmp/                       # backup/restore working space
```

Redis contains background queues as well as caches. Its data is retained with
`maxmemory 512mb`, `noeviction`, AOF `everysec` and upstream RDB snapshots; it is
not a disposable cache. The memory limit does not bound total RSS or rewrite
peaks. Monitor memory, job latency, failed persistence and disk usage.

Back up PostgreSQL through Pigsty/pgBackRest and create Discourse archives that
include uploads. Keep an independent off-host copy. A live copy of a single
`.aof` is not a valid backup of a multi-part AOF; use a stable RDB or a consistent
complete file set. Isolated restore tests need their own database, Redis and
shared directory, with outbound email disabled: Discourse's restore process
clears Redis and queues.

Local uploads are the default. MinIO/Silo/S3 can be configured later after
checking endpoint/bucket DNS, TLS, CORS and private-upload permissions. S3
uploads are not included in archives unless that is explicitly configured or
the objects are backed up separately.

## Move the application

1. Record the running image ID/source versions and back up the database.
2. Stop the old app and confirm all Web/Sidekiq/Redis processes have exited.
3. Copy `/data/app/discourse` over a private channel,
   preserving ownership/permissions; exclude the ephemeral Nginx socket.
4. Export/load the same image using `make save` / `make load`. The archive at
   `/tmp/docker/discourse.tgz` is private: the Launcher-built image contains
   application configuration. Keep it outside Git and public registries.
5. Configure the new host's database connectivity and Nginx socket upstream.
   Use `make start` with the unchanged configuration and image, then verify
   login, posts, uploads, mail, background jobs and backups before switching
   the public proxy. Keep the old app stopped.

If the database endpoint or other configuration changes, pin
`DISCOURSE_VERSION` to the old receipt's exact `commit` and use `make up` to
rebuild that same application version. Do not combine a move with an unintended
upgrade of the application version.

When PostgreSQL stays in place, no Discourse restore is needed for this move.
Moving or retiring the database host is a separate Pigsty switchover/restore
operation. Never copy live PGDATA as part of the application directory.

## Sources

- [Official Docker setup and templates](https://github.com/discourse/discourse_docker)
- [External PostgreSQL requirements](https://meta.discourse.org/t/configure-discourse-to-use-a-separate-postgresql-server/46375)
- [Nginx coexistence and Unix socket](https://meta.discourse.org/t/run-other-websites-on-the-same-machine-as-discourse/17247)
- [Sidekiq Redis persistence and memory policy](https://github.com/sidekiq/sidekiq/wiki/Using-Redis)

## Known baseline limitations

- After a failed rebuild, the old `.build.json` can still allow `make up` or
  `make start` to launch the previous image against a potentially migrated
  database. Do not use those commands to recover from a failed bootstrap until
  the schema/image state has been checked. Build receipt invalidation needs to
  be fixed before relying on this workflow for production upgrades.
- `files/discourse.sql` assumes both database and owner are named `discourse`.
  Keep these names, or adapt the SQL alongside the inventory and `.env`.
  Verify that the baseline succeeded: the database playbook currently ignores
  baseline errors, which can leave shared-role grants in place.
- The default `oltp` Tuned profile sets `vm.overcommit_memory=0`, while Redis
  persistence needs `1`. Configure a persistent override and verify it after
  restarting Tuned or rebooting; the application template does not do this yet.

## Validation snapshot

The Pigsty v4.6.0 release baseline is PostgreSQL 18.7. The tests below record the earlier environment.

On 2026-10-14, an isolated Linux ARM64 Docker test built application commit
`3279b67fba94db51b9a545b90f8eaf4352cae0bb` with the pinned Launcher and external
PostgreSQL 18.6. Schema migrations, the initial installation page and the health
endpoint passed through the rendered Pigsty Nginx socket portal. Redis ran as
one process with loopback binding, AOF, `noeviction` and a 512 MB limit; a probe
key survived removal/recreation of the application container. The database
baseline also passed a repeated-run test and denied shared-role access to newly
created owner objects. Compose, Ansible and Nginx configuration checks passed.

A subsequent native x86-64 deployment on 2026-10-14 built the same pinned
application and Launcher commits against Pigsty PostgreSQL 18.6. Public HTTPS,
Chinese assets, administrator login/API, Redis persistence configuration and
the application's Ruby SMTP TLS/authentication checks passed. Application
archives included SQL and local uploads; their copies on a separate host
matched SHA-256. A repeated `make up` reused the built image.

Real inbox delivery, the complete ordinary-user posting/upload flow, load
capacity, backup restore and failover were not exercised. ARM64 remains
experimental upstream. Linux Redis persistence needs `vm.overcommit_memory=1`;
ensure the active Tuned profile also preserves that value after restart.
