# Dify

Dify: https://dify.ai/

The Innovation Engine for GenAI Applications, Dify is an open-source LLM app development platform. Orchestrate LLM apps from agents to complex AI workflows, with an RAG engine.

- Targets [Dify v1.17.0](https://github.com/langgenius/dify/releases/tag/1.17.0)
  with plugin daemon v0.6.10-local (release checked on 2026-08-27).
- Validated on Ubuntu 24.04 arm64 with Pigsty PostgreSQL 18.6 and pgvector 0.8.6:
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

Dify v1.17.0 updates the Agent runtime, adds workspace Skills and Agent Home
Snapshots, and includes database migrations. The local sandbox's `/home/dify`
and `/workspace` use named volumes; include these volumes in your backup.
Before upgrading an existing
deployment, verify that the Pigsty PostgreSQL backup is recent, back up
`/data/dify`, and replace the three Agent development secrets with independent
random values. With `MIGRATION_ENABLED=true`, migrations run automatically when
the API container starts; they can also be run explicitly after pulling images:

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
