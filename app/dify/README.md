# Dify

Dify: https://dify.ai/

The Innovation Engine for GenAI Applications, Dify is an open-source LLM app development platform. Orchestrate LLM apps from agents to complex AI workflows, with an RAG engine.

- Targets [Dify v1.19.0](https://github.com/langgenius/dify/releases/tag/1.19.0)
  with plugin daemon v0.6.14-local and sandbox v0.2.15.
- Upstream 1.19 splits Compose settings into `envs/**/*.defaults` plus
  per-service `.env` files. This template keeps a single `.env`, which `app.yml`
  updates from `apps.dify.conf`, and carries the required defaults in
  `docker-compose.yml`; it does not use upstream's `envs/` directory.
- Historical validation: Dify v1.17.0 on 2026-08-27, Ubuntu 24.04 arm64,
  Pigsty PostgreSQL 18.6 and pgvector 0.8.6:
  schema head `a4f8d2c9e1b0`, setup/login, collaboration handshake, an actual
  Code workflow, Celery roundtrip, Agent Home Snapshot restore, and SSRF /
  cross-workspace isolation. No external paid model is needed for these checks.
- Dify v1.16+ handles PostgreSQL 18's built-in `uuidv7()` without a local patch.
- The Dify Agent feature is Beta and is isolated behind dedicated internal
  networks and an SSRF proxy; expose it only to trusted users. Its shellctl
  control network still permits direct local-sandbox access to agent_backend.
- `DIFY_PORT` changes only the published HTTP port; API/WebSocket services keep
  port 5001 internally. `SSRF_HTTP_PORT` also updates the bundled sandbox proxy
  URLs unless you explicitly override those URLs.
- Beat intentionally has no worker-ping healthcheck: a worker's response does
  not prove the scheduler is running. Monitor scheduled task cadence separately.
- [Self-Hosting Dify](https://pigsty.io/docs/app/dify)
- [GitHub: langgenius/Dify](https://github.com/langgenius/dify/)
- [Pigsty: Dify Docker Compose Template](https://github.com/pgsty/pigsty/tree/master/app/dify)


```bash
curl -fsSL https://repo.pigsty.io/get | bash; cd ~/pigsty
cd ~/pigsty
./bootstrap               # prepare local repo & ansible
./configure -c app/dify   # IMPORTANT: CHANGE CREDENTIALS!!
./deploy.yml              # install pigsty & pgsql
./docker.yml              # install docker & docker-compose
./app.yml                 # install dify with docker compose
```

------

## Get Started

Define & Create required PostgreSQL and Docker resources with Pigsty:

```yaml
all:
  children:

    # the dify application
    dify:
      hosts: { 10.10.10.10: {} }
      vars:
        app: dify   # specify app name to be installed (in the apps)
        apps:       # define all applications
          dify:     # app name, should have corresponding ~/app/dify folder
            conf:   # override /opt/dify/.env config file
              # A secret key for signing and encryption, gen with `openssl rand -base64 42` (CHANGE PASSWORD!)
              SECRET_KEY: sk-9f73s3ljTXVcMT3Blb3ljTqtsKiGHXVcMT3BlbkFJLK7U
              DIFY_AGENT_API_TOKEN: change-this-agent-api-token
              # Valid 32-byte development key; replace with secrets.token_urlsafe(32)
              DIFY_AGENT_SERVER_SECRET_KEY: MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY
              # Required nonblank since 1.18; replace with `openssl rand -hex 32`
              DIFY_AGENT_LOCAL_SANDBOX_AUTH_TOKEN: change-this-local-sandbox-auth-token
              DIFY_DATA: /data/dify
              COMPOSE_PROFILES: collaboration
              NEXT_PUBLIC_SOCKET_URL: ws://dify.pigsty
              TRIGGER_URL: http://dify.pigsty
              ENDPOINT_URL_TEMPLATE: http://dify.pigsty/e/{hook_id}
              DB_TYPE: postgresql
              DB_USERNAME: dify
              DB_PASSWORD: difyai123456
              DB_HOST: 10.10.10.10
              DB_PORT: 5432
              DB_DATABASE: dify
              DB_SSL_MODE: disable
              VECTOR_STORE: pgvector
              PGVECTOR_HOST: 10.10.10.10
              PGVECTOR_PORT: 5432
              PGVECTOR_USER: dify
              PGVECTOR_PASSWORD: difyai123456
              PGVECTOR_DATABASE: dify
              PGVECTOR_MIN_CONNECTION: 2
              PGVECTOR_MAX_CONNECTION: 10
              NGINX_SERVER_NAME: localhost
              DIFY_PORT: 5001 # expose DIFY nginx service with port 5001 by default
              #STORAGE_TYPE: s3
              #S3_ENDPOINT: 'https://sss.pigsty'
              #S3_BUCKET_NAME: 'dify'
              #S3_ACCESS_KEY: 'dify'
              #S3_SECRET_KEY: 'S3User.Dify'
              #S3_REGION: 'us-east-1'
              #S3_ADDRESS_STYLE: 'path'

    pg-meta:
      hosts: { 10.10.10.10: { pg_seq: 1, pg_role: primary } }
      vars:
        pg_cluster: pg-meta
        pg_extensions: [ pgvector ]
        pg_users:
          - { name: dify ,password: difyai123456 ,pgbouncer: true ,roles: [ dbrole_admin ] ,superuser: true ,comment: dify superuser }
        pg_databases:
          - { name: dify        ,owner: dify ,extensions: [ { name: vector } ] ,comment: dify main database  }
          - { name: dify_plugin ,owner: dify ,comment: dify plugin daemon database }
        pg_hba_rules:
          - { user: dify ,db: all ,addr: 172.16.0.0/12  ,auth: pwd ,title: 'allow dify access from local docker networks' }
          - { user: dbuser_view , db: all ,addr: infra ,auth: pwd ,title: 'allow grafana dashboard access cmdb from infra nodes' }
    
    infra: { hosts: { 10.10.10.10: { infra_seq: 1 } } }
    etcd:  { hosts: { 10.10.10.10: { etcd_seq: 1 } }, vars: { etcd_cluster: etcd } }
    #minio: { hosts: { 10.10.10.10: { minio_seq: 1 } }, vars: { minio_cluster: minio } }
```


------

## Expose Dify Web Service

Change `infra_portal` in `pigsty.yml`, with the new `dify` line:

```yaml
infra_portal:                     # infra services exposed via portal
  home : { domain: i.pigsty }     # default domain name
  
  dify         : { domain: dify.pigsty ,endpoint: "10.10.10.10:5001", websocket: true }
```

Then expose dify web service via Pigsty's Nginx server:

```bash
./infra.yml -t nginx
```

Don't forget to add `dify.pigsty` to your DNS or local `/etc/hosts` / `C:\Windows\System32\drivers\etc\hosts` to access via domain name.

If you are using a public domain, consider using [Certbot](https://pigsty.io/docs/infra/admin/cert) to get a free SSL certificate.

```bash
certbot --nginx --agree-tos --email your@email.com -n -d dify.your.domain    # replace with your email & dify domain
```

Then add `certbot` field to the `dify` entry:

```yaml
infra_portal:
  #...
  dify : { domain: dify.pigsty.cc ,endpoint: "10.10.10.10:5001", websocket: true , certbot: 'dify.pigsty.cc' }
```

To take over nginx config back to pigsty:

```bash
./infra.yml -t nginx_config     # regenerate nginx config align with certbot modification
```

## Upgrade Notes

### From 1.17.x to 1.19.0

Dify 1.19.0 includes the 1.18.0 changes. Read the upgrade guides in both the
[1.18.0](https://github.com/langgenius/dify/releases/tag/1.18.0) and
[1.19.0](https://github.com/langgenius/dify/releases/tag/1.19.0) release notes.

- **Back up, then upgrade all components together.** Verify a recent Pigsty
  PostgreSQL backup and back up `/data/dify`, `/opt/dify/.env`,
  `/opt/dify/volumes`, and the two Agent sandbox named volumes. API, worker,
  Beat, web, Agent backend, and local sandbox must all run 1.19.0 with plugin
  daemon 0.6.14-local: the Agent backend rejects the old run protocol, and older
  Agent runtimes cannot read session snapshots saved by 1.18+. Historical
  Agent-specific AskHuman forms no longer resume. Use a maintenance window:
  optionally stage the files with `./app.yml -l dify -t app_install,app_config`
  and pre-pull with `docker compose pull` in `/opt/dify`, stop the old stack
  with `docker compose stop -t -1`, then rerun `./app.yml -l dify`. Keep
  overrides in `apps.dify.conf`, because `app.yml` rewrites `/opt/dify/.env`
  from the template.
- **Plugin daemon runs as non-root.** Plugin daemon 0.6.12+ runs as `dify`
  (uid 1001) instead of root, so a root-owned `${DIFY_DATA}/plugin_daemon`
  breaks plugin installs (`mkdir /app/storage/assets: permission denied`,
  langgenius/dify#45597). `init_permissions` now also changes that directory
  to `1001:1001` once, records it with a `.init_permissions` flag file there,
  and `plugin_daemon` waits for it. This ports the unmerged upstream fix
  langgenius/dify#45615. The first start after upgrading can take a while on
  large plugin directories.
- **Local sandbox token.** `local_sandbox` now runs
  `shellctl serve --require-auth-token` and exits when
  `DIFY_AGENT_LOCAL_SANDBOX_AUTH_TOKEN` is blank. Compose interpolates the same
  `.env` value into `agent_backend`; set it only through `apps.dify.conf`.
  Replace the placeholder with `openssl rand -hex 32`, and keep an existing
  value unchanged during upgrades.
- **Password pepper.** The template does not set `PASSWORD_PEPPER`. Leave it
  unset on existing installations: setting, changing, or removing it
  invalidates every stored password hash. If a new installation adopts one,
  keep it unchanged and back it up with the database. In this single-`.env`
  template, `plugin_daemon` also receives it.
- **Client IP handling.** The bundled Nginx now replaces `X-Forwarded-For` with
  `$remote_addr` and derives `Host` / `X-Forwarded-Port` from the client's Host
  header. `api` and `api_websocket` default to
  `RESPECT_XFORWARD_HEADERS_ENABLED=true`. Behind Pigsty's portal Nginx,
  `$remote_addr` is the proxy's address, so visitors still share one
  rate-limit bucket unless you add an operator-managed
  `nginx/conf.d/real-ip.conf` that trusts only that proxy
  (`set_real_ip_from <proxy address>; real_ip_header X-Forwarded-For; real_ip_recursive on;`).
  Never trust `0.0.0.0/0`. The API port stays unpublished, but containers on
  Dify's internal networks, including the code sandbox, can still call it
  directly. Set `RESPECT_XFORWARD_HEADERS_ENABLED: false` to opt out.
- **Tracing queue.** New tracing tasks use `OPS_TRACE_QUEUE=ops_trace_v2`, the
  application default. API, worker, and Beat read the same `.env`, so they
  agree. Custom `CELERY_QUEUES` or `CELERY_WORKER_QUEUES` lists must include
  `ops_trace_v2`, `human_input_delivery`, and `human_input_contact_sync`. New
  workers do not export legacy `ops_trace` messages; if tracing providers are
  configured, let in-flight work finish before stopping the old stack, and do
  not purge the old queue.
- **Database migrations.** With `MIGRATION_ENABLED=true`, the API applies them
  at startup: 22 revisions and two merges to `b9d3f7a5c102` (1.18.0), then six
  revisions to `53c10126d551` (1.19.0). KnowledgeFS control-plane tables are
  created in the Dify database even though KnowledgeFS stays disabled. New
  PostgreSQL indexes on `workflow_runs`, `message_files`,
  `workflow_node_execution_offload`, and `workflow_draft_variable_files` are
  built `CONCURRENTLY`; they scan those tables, consume I/O, and commit
  independently of the revision stamp. If a build is interrupted, inspect the
  invalid index and confirm no build is still running, drop only that index
  with `DROP INDEX CONCURRENTLY`, and rerun `flask db upgrade`; never drop a
  healthy index. Revision `53c10126d551` keeps one tracing configuration per
  app/provider and deletes the superseded rows; a downgrade does not restore
  them.
- **App packages.** App exports now use `.ifpkg` package format v2. Older Dify
  installations may reject these packages; v1 imports and explicit YAML
  export remain available. The 1.18+ `difyctl` client requires a new login.
- **Web flags and callbacks.** `NEXT_PUBLIC_ENABLE_ACCESS_TOKEN` and
  `NEXT_PUBLIC_ENABLE_HITL_IM` default to `false`. Human Input IM webhooks
  build their callback URLs from `TRIGGER_URL`; set it to the public HTTPS
  origin. The bundled Nginx routes `/callbacks/human-input/v2/im/` to the API.
- **Docker Compose.** Upstream 1.19 requires Compose 2.35.0+ for its
  `envs/*.defaults` precedence. This template does not use that mechanism,
  but a current Compose v2 plugin is still recommended (`docker compose version`).
- **KnowledgeFS is not included.** The Beta Agent Knowledge Base needs a
  separate service, its own database and migrations, Capability v2 signing
  keys, model profiles, and an amd64-only image; `KNOWLEDGE_FS_ENABLED` stays
  `false`. To evaluate it, add upstream's `knowledge_fs` services in a
  `docker-compose.override.yml` and follow the upstream
  [KnowledgeFS guide](https://github.com/langgenius/dify/blob/1.19.0/docker/README.md#enable-the-knowledgefs-integration).
- **Existing data.** Re-import or re-index documents affected by the EPUB, EML,
  DOCX, CSV, Markdown, or Notion extraction fixes. Trigger subscriptions lost
  before the upgrade must be rebound and their workflows republished.

### Earlier releases

Dify v1.17.1 fixes document extraction, Human Input workflows, collaboration,
and Agent behavior. It also runs the pre-1.15 legacy model type migration as
part of `flask db upgrade`; a separate `flask data-migrate legacy-model-types`
step is no longer needed. Previously mis-extracted CSV, Notion, or XLS documents
must be re-imported after upgrading; the new image does not repair indexed text.
See the [1.17.1 release notes](https://github.com/langgenius/dify/releases/tag/1.17.1).

The shared `SSRF_PROXY_ALLOW_PRIVATE_IPS` and `SSRF_PROXY_ALLOW_PRIVATE_DOMAINS`
allowlists now apply to both the workflow proxy and the Agent local-sandbox
proxy. Leave them empty for the default private-network deny policy. With empty
allowlists, the Agent proxy restricts internal access to `/files/` and
`/agent-stub/`. Explicitly allowlisting `api`, `agent_backend`, or a network
covering their IPs also permits their other ordinary paths; the preceding
traversal deny rules still take precedence. Use precise, intentional targets.
`MARKDOWN_FORM_FIELD_NAME_MAX_LENGTH` defaults to 128;
`NEXT_PUBLIC_ENABLE_AGENT_V2_IN_CHATFLOW` defaults to false, matching upstream.

Dify v1.17.0 updated the Agent runtime, added workspace Skills and Agent Home
Snapshots, and included database migrations. The local sandbox's `/home/dify`
and `/workspace` use named volumes; include these volumes in your backup.
Before upgrading an existing
deployment, verify that the Pigsty PostgreSQL backup is recent, back up
`/data/dify`, and replace the three Agent development secrets with independent
random values. With `MIGRATION_ENABLED=true`, migrations run automatically when
the API container starts; they can also be run explicitly after recreating the API container with the new image:

```bash
docker compose exec api flask db upgrade
```

For an existing 1.16 deployment, rename `EDITION` to `DEPLOYMENT_EDITION`,
`DIFY_AGENT_SHELLCTL_AUTH_TOKEN` to `DIFY_AGENT_LOCAL_SANDBOX_AUTH_TOKEN`, and
`DIFY_AGENT_SHELLCTL_ENTRYPOINT` to `DIFY_AGENT_LOCAL_SANDBOX_ENDPOINT` in your
deployment overrides. The Compose template accepts the old shellctl names as
fallbacks, but the new names take precedence. `AGENT_BACKEND_RUN_TIMEOUT_SECONDS`
is replaced by `DIFY_AGENT_RUN_TIMEOUT_SECONDS`; the Agent, app, and workflow
execution deadlines now default to 3600 seconds. Keep `DIFY_AGENT_RUNTIME_BACKEND`
set to `local` for the bundled self-hosted sandbox.

Deployments upgrading from a version older than 1.15 must also run the 1.15
plugin auto-upgrade backfill once after the schema upgrade (do not repeat it if
it was already completed during an earlier 1.15 upgrade):

```bash
docker compose exec api flask backfill-plugin-auto-upgrade
```

The Pigsty template keeps PostgreSQL and pgvector external. Silo or another S3-compatible store remains opt-in; do not point Dify at the pgBackRest backup bucket unless that is intentional.
