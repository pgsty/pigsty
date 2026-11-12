# InsForge

> [InsForge](https://github.com/InsForge/InsForge) -- Open-source Backend-as-a-Service for AI coding agents

Pigsty allows you to self-host **InsForge** with an existing managed HA PostgreSQL cluster, and launch the stateless services with docker-compose.
This template targets the prebuilt `v2.3.5` InsForge OSS image with external PostgreSQL managed by Pigsty.
The Pigsty v4.6.0 release baseline is PostgreSQL 18.7.
Historical validation: InsForge v2.3.1 on 2026-08-27, Ubuntu 24.04 arm64,
Pigsty PostgreSQL 18.6, and all 67 application migrations through
`064_compute-services-multi-driver`.
Runtime checks cover dashboard login, custom-schema REST/RLS, managed-table
policy permissions, private storage uploads/downloads, Deno functions with
encrypted secrets, and a real sub-minute HTTP schedule.

InsForge is an agent-oriented BaaS platform built upon PostgreSQL.
It provides authentication, database APIs, storage, model gateway, edge functions, compute, and site deployment features.
Design your database schema and frontend, and skip backend development entirely.

Self-hosted InsForge with Pigsty enjoys full PostgreSQL monitoring, IaC, PITR, and high availability,
with the latest PG 17/18 kernels and [626](https://pigsty.io/ext/list) PostgreSQL extensions ready to use.


-------

## Quick Start

Download & [install](https://pigsty.io/docs/setup/install) Pigsty with the `insforge` config template:

```bash
curl -fsSL https://repo.pigsty.io/get | bash; cd ~/pigsty
./bootstrap                 # prepare local repo & ansible
./configure -c app/insforge # use the insforge config template
vi pigsty.yml               # IMPORTANT: CHANGE CREDENTIALS!!
./infra.yml                 # create the CA and initialize the infra node first
./node.yml -l pg-meta        # provision the PostgreSQL nodes
./pgsql.yml -l pg-meta -t pg_install # install PG packages without initializing
# Install the required utility hook on EACH PostgreSQL node (see below).
sudo apt-get install -y postgresql-server-dev-18 build-essential curl patch
sudo env PG_CONFIG=/usr/lib/postgresql/18/bin/pg_config bash app/insforge/pgutils/install.sh
./deploy.yml                # initialize PG with the utility hook and deploy infra
./docker.yml                # install docker & docker-compose
./app.yml                   # install insforge with docker-compose
```

Visit `http://<your-ip>:7130` for the InsForge dashboard.

> Default credentials: `admin@example.com` / `pigsty`


-------

## Architecture

```
                    ┌──────────────────────────────────────────────┐
                    │                 InsForge Stack               │
┌──────────┐       │  ┌──────────┐  ┌──────────┐  ┌───────────┐  │
│  Nginx   │──────▶│  │ InsForge │  │PostgREST │  │   Deno    │  │
│ (Pigsty) │  :7130│  │ App+Web  │  │ REST API │  │  Runtime  │  │
└──────────┘       │  │  :7130   │  │  :5430   │  │   :7133   │  │
                    │  └────┬─────┘  └────┬─────┘  └─────┬─────┘  │
                    │       │             │              │         │
                    └───────┼─────────────┼──────────────┼─────────┘
                            │             │              │
                            ▼             ▼              ▼
                    ┌──────────────────────────────────────────────┐
                    │  PostgreSQL (Pigsty Managed HA Cluster)      │
                    │  Patroni + pgBackRest + pgBouncer + HAProxy  │
                    └──────────────────────────────────────────────┘
```

- **InsForge App** (`ghcr.io/insforge/insforge-oss:v2.3.5`): Main application server with dashboard UI and API (port 7130)
- **PostgREST** (`postgrest/postgrest:v12.2.12`): Auto-generated REST API from PostgreSQL schema (port 5430)
- **Deno Runtime** (`denoland/deno:alpine-2.0.6`): Pinned runtime executing the bundled InsForge v2.3.5 function host (port 7133)
- **PostgreSQL**: Managed externally by Pigsty with HA, PITR, monitoring


-------

## Configuration

### Pigsty Config Template

Use the config template at `conf/app/insforge.yml`:

```bash
./configure -c app/insforge
```

This sets up:
- InsForge app group with Docker deployment
- INFRA and ETCD groups for the standalone node and Patroni's coordination store
- PostgreSQL cluster `pg-meta` with required users, roles, and database
- Nginx reverse proxy at `isf.pigsty`
- Required extensions: `pgcrypto`, `http`, `pg_cron`
- Required shared-preload library: `insforge_pg_utils` (installed before PostgreSQL initialization)

The initial `infra.yml` step is required on a fresh installation: `node.yml`
expects its CA certificate to exist. For an existing Pigsty deployment, retain
its existing INFRA/ETCD inventory and do not repeat initialization playbooks.

### Key Parameters to Customize

Edit `pigsty.yml` before deploying:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `JWT_SECRET` | `your-secret-key...` | **MUST CHANGE!** JWT signing key (32+ chars) |
| `ENCRYPTION_KEY` | `your-encryption-key...` | **MUST CHANGE!** Separate secret for encrypted runtime credentials |
| `ROOT_ADMIN_USERNAME` | `admin@example.com` | Root admin login |
| `ROOT_ADMIN_PASSWORD` | `pigsty` | Root admin password |
| `POSTGRES_PASSWORD` | `DBUser.Insforge` | Database user password |
| `INSFORGE_IMAGE` | empty | Optional app image override when `ghcr.io` is slow or blocked |
| `DENO_RUNTIME_IMAGE` | empty | Optional Deno runtime image override |
| `infra_portal.insforge.domain` | `isf.pigsty` | Nginx domain name |
| `ACCESS_API_KEY` | empty | Optional MCP / API key override |
| `ACCESS_ANON_KEY` | empty | Optional public anon key override |
| `AWS_S3_BUCKET` | empty | Optional S3 bucket for object storage |
| `DENO_DEPLOY_TOKEN` | empty | Optional Deno Deploy token |

InsForge also supports an opt-in Docker compute provider. Its environment
variables and a commented socket mount are included in the template, but the
socket is **not** mounted by default: Docker socket access is root-equivalent on
the host. Review this boundary before enabling it; the base stack does not need
that access.

### Domain Name

Replace the default domain with your own:

```bash
sed -ie 's/isf.pigsty/isf.yourdomain.com/g' pigsty.yml
```


-------

## Database Setup

InsForge requires these PostgreSQL components:

### Users & Roles

| Role | Login | Purpose |
|------|-------|---------|
| `dbuser_insforge` | Yes (superuser) | InsForge application user |
| `anon` | No | PostgREST anonymous role |
| `authenticated` | No | PostgREST authenticated role |
| `project_admin` | No | PostgREST admin role with `BYPASSRLS` |

### Database

- **Name**: `insforge`
- **Owner**: `dbuser_insforge`
- **Baseline**: `insforge.sql` (grants, default privileges, project admin ACLs)
- **Extensions**: `pgcrypto`, `http`, `pg_cron`

InsForge requires `insforge_pg_utils` for `project_admin` to manage RLS policies
on managed tables without taking ownership of them, and to manage extensions.
Application migrations do **not** replace this library. The helper
`pgutils/install.sh` downloads the official `insforge-db` v15.13.4 source at
commit `86f0653c2dd3cbe15dab6fcc34d880d8b1b2ea9f`, verifies each source file's
SHA-256, and applies the PostgreSQL 16-18 API compatibility patch before building
with PGXS. It exposes no SQL objects, so no `CREATE EXTENSION` is needed.

Copy the complete `pgutils/` directory (script, patch, and checksums) to each
database node. Run the helper on **every database node**, after installing the matching
PostgreSQL development package and before the first `./deploy.yml`. On
Debian/Ubuntu use `postgresql-server-dev-18` and
`PG_CONFIG=/usr/lib/postgresql/18/bin/pg_config`; on EL/RPM systems use
`postgresql18-devel`, `gcc`, `make`, `curl`, `patch`, and
`PG_CONFIG=/usr/pgsql-18/bin/pg_config`. Replace `18` with your selected major.
The script retains its build directory and refuses to overwrite a different
installed library. It does not change PostgreSQL configuration or restart a
running cluster; plan those separately when upgrading an existing deployment.

### Function Dependencies

The Deno container pre-caches both the host and worker modules before starting.
The SDK is pinned to `@insforge/sdk@1.5.2`, and `functions/deno.lock` fixes the
dependency graph. The first bootstrap needs access to `deno.land` and
`registry.npmjs.org`; configure `DENO_HTTP_PROXY` / `DENO_HTTPS_PROXY` if needed.
Subsequent starts reuse the `deno_cache` volume. An image-only `make save` archive
does not include this cache: prepare and transfer it separately for offline use.
The runtime `/health` endpoint is a process check, not a database/function test.

### Shared Libraries

Both `pg_cron` and `insforge_pg_utils` require `shared_preload_libraries`:

```yaml
pg_libs: 'pg_cron, insforge_pg_utils, pg_stat_statements, auto_explain'
pg_parameters:
  cron.database_name: insforge
  cron.use_background_workers: true
  app.encryption_key: your-encryption-key-here-must-be-32-char-or-above
  insforge.policy_grant_role: project_admin
  insforge.extension_grant_role: project_admin
  insforge.internal_schemas: 'ai,auth,compute,deployments,email,functions,memory,payments,realtime,schedules,storage,system'
```

The background-worker setting lets scheduled jobs run under Pigsty's normal
password/peer authentication rules without adding a loopback `trust` rule or
storing an application password in the PostgreSQL OS user's `.pgpass` file.
Reserve enough `max_worker_processes` slots for cron, replication, and other
preloaded extensions.

### HBA Rules

Allow Docker containers to access PostgreSQL:

```yaml
pg_hba_rules:
  - { user: dbuser_insforge, db: all, addr: 172.16.0.0/12, auth: pwd, title: 'allow insforge from docker' }
```


-------

## Docker Services

### Ports

| Service | Port | Description |
|---------|------|-------------|
| InsForge Dashboard + API | 7130 | Main application (dashboard & API) |
| PostgREST | 127.0.0.1:5430 | Internal REST data API; use the main InsForge API remotely |
| Deno Runtime | 127.0.0.1:7133 | Internal edge functions runtime |

### Volumes

| Volume | Mount Point | Description |
|--------|-------------|-------------|
| `storage-data` | `/insforge-storage` | File storage |
| `insforge-logs` | `/insforge-logs` | Application logs |
| `deno_cache` | `/deno-dir` | Deno module cache |

### Environment Variables

All configuration is in `/opt/insforge/.env`. Key variables:

```bash
# Secrets (MUST CHANGE)
JWT_SECRET=your-secret-key-here-must-be-32-char-or-above
ENCRYPTION_KEY=your-encryption-key-here-must-be-32-char-or-above
ROOT_ADMIN_USERNAME=admin@example.com
ROOT_ADMIN_PASSWORD=pigsty

# Optional image overrides when ghcr.io is slow or blocked
#INSFORGE_IMAGE=ghcr.io/insforge/insforge-oss:v2.3.5
#DENO_RUNTIME_IMAGE=denoland/deno:alpine-2.0.6

# Database (must match pigsty.yml pg_users)
POSTGRES_HOST=10.10.10.10
POSTGRES_PORT=5432
POSTGRES_DB=insforge
POSTGRES_USER=dbuser_insforge
POSTGRES_PASSWORD=DBUser.Insforge

# Optional: LLM Gateway
OPENROUTER_API_KEY=

# Optional: MCP / Cloud API access
ACCESS_API_KEY=
ACCESS_ANON_KEY=
CLOUD_API_HOST=

# Optional: object storage / CDN
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_REGION=
AWS_S3_BUCKET=
S3_ACCESS_KEY_ID=
S3_SECRET_ACCESS_KEY=
S3_ENDPOINT_URL=
S3_FORCE_PATH_STYLE=true
AWS_CLOUDFRONT_URL=
AWS_CLOUDFRONT_KEY_PAIR_ID=
AWS_CLOUDFRONT_PRIVATE_KEY=
MAX_FILE_SIZE=

# Optional: edge functions
DENO_DEPLOY_TOKEN=
DENO_DEPLOY_ORG_ID=

# Optional: site deployment / compute / payments
VERCEL_TOKEN=
FLY_API_TOKEN=
FLY_ORG=
STRIPE_TEST_SECRET_KEY=
STRIPE_LIVE_SECRET_KEY=

# Optional: OAuth Providers
GITHUB_CLIENT_ID=
GITHUB_CLIENT_SECRET=
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
```


-------

## Operations

### Start / Stop

```bash
cd /opt/insforge
make up       # docker compose up -d
make down     # docker compose down
make restart  # docker compose restart
make log      # docker compose logs -f
make info     # docker compose ps
```

### Upgrade to v2.3.5

v2.3.5 is a patch release with dependency security fixes. PostgREST
`v12.2.12`, Deno `alpine-2.0.6`, and the vendored `functions/` runtime are
unchanged. When upgrading from a release before v2.3.3, also follow the v2.3.3
section below.

Take the same backups as below, then pull and recreate the InsForge container.
Its startup migration runner applies
`066_storage-objects-default-owner-policies`. It only acts when
`storage.objects` has **no** policies: it then creates owner-only
`storage_objects_owner_*` policies for `authenticated` (reads also allow
objects in public buckets, through the new `storage.public_buckets()` helper)
and enables RLS on `storage.objects`. Projects that already have any policy on
the table are left unchanged. Objects written through the S3 protocol have
`uploaded_by = NULL`, so end users cannot see them in private buckets or
modify them; API-key / `project_admin` callers bypass RLS. Review custom
policies if a project mixes the user API and the S3 protocol on the same keys.
The `files/insforge.sql` baseline does not touch `storage`; do not replay it.

```sql
SELECT name, run_on FROM system.migrations
WHERE name = '066_storage-objects-default-owner-policies';

SELECT polname FROM pg_policy
WHERE polrelid = 'storage.objects'::regclass ORDER BY 1;
```

Source: [v2.3.5 migration 066](https://github.com/InsForge/InsForge/blob/c1c886e775d286433e4b50c78c24335783e8fc00/backend/src/infra/database/migrations/066_storage-objects-default-owner-policies.sql).

### Upgrade to v2.3.3

Back up the PostgreSQL database (including `system.migrations`), file storage,
and deployment overrides before upgrading. Preserve the existing JWT and
credential-encryption keys. Pull and recreate the InsForge container with the
new image; its startup migration runner applies
`065_restrict-http-extension-to-admin` to existing databases. PostgREST and Deno
retain their coordinated upstream versions.

Migration 065 revokes `PUBLIC` execution of the `http` extension's outbound and
curl-option functions, while granting `project_admin` execution. Legitimate anon
keys and normal user JWTs previously reached these functions through the main
InsForge RPC API when the default `PUBLIC` grant remained. The new-install
`files/insforge.sql` baseline applies the same restriction immediately.

Let the v2.3.3 startup runner apply and record migration 065. Do not replay the
full `files/insforge.sql` baseline on an existing database.

Verify the migration ledger and actual permissions after startup:

```sql
SELECT name, run_on FROM system.migrations
WHERE name = '065_restrict-http-extension-to-admin';

SELECT p.oid::regprocedure AS function,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_exec,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS user_exec,
       has_function_privilege('project_admin', p.oid, 'EXECUTE') AS admin_exec
FROM pg_proc p
JOIN pg_depend d ON d.classid = 'pg_proc'::regclass AND d.objid = p.oid
JOIN pg_extension e ON e.oid = d.refobjid AND d.deptype = 'e'
WHERE e.extname = 'http'
  AND p.proname IN ('http', 'http_get', 'http_post', 'http_put', 'http_patch',
                   'http_delete', 'http_head', 'http_set_curlopt',
                   'http_reset_curlopt', 'http_list_curlopt')
ORDER BY 1;
```

The first query must return 065; each function must report `false`, `false`,
`true`. Explicit grants or role memberships from a customized deployment can
still grant access after revoking `PUBLIC`; review those if either non-admin
column is true. Source: [v2.3.3 migration 065](https://github.com/InsForge/InsForge/blob/636d1e207d2bca246f7b8ccd0e0b6572528809fa/backend/src/infra/database/migrations/065_restrict-http-extension-to-admin.sql).

### Offline Deployment

Save Docker images for air-gapped installation:

```bash
make pull     # pull latest images
make save     # save images to /tmp/docker/insforge/
make tarball  # create /tmp/insforge.tgz
# transfer to target machine, then:
make load     # load images from /tmp/docker/insforge/
make up       # start services
```

### Nginx Reverse Proxy

The config template includes an nginx entry at `isf.pigsty`:

```yaml
infra_portal:
  insforge:
    domain: isf.pigsty
    endpoint: "10.10.10.10:7130"
    websocket: true
    certbot: isf.pigsty
```

After deploying infra, access InsForge at `https://isf.pigsty`.
Add the domain to `/etc/hosts` or DNS for local access.

### HTTPS with Certbot

```bash
make cert     # apply for Let's Encrypt certificate
```


-------

## Backup & Recovery

PostgreSQL is managed by Pigsty with automatic backup:

```yaml
pg_crontab: [ '00 01 * * * /pg/bin/pg-backup full' ]  # daily full backup at 1am
```

Check backup status:

```bash
pig pb info           # backup information
pg-backup full        # manual full backup
pg-backup diff        # manual differential backup
```

Point-in-time recovery is available via pgBackRest. See [PITR docs](https://pigsty.io/docs/pgsql/backup/restore/).


-------

## Troubleshooting

### Container not starting

```bash
sudo docker logs insforge          # check application logs
sudo docker logs insforge-postgrest # check PostgREST logs
sudo docker logs insforge-deno     # check Deno runtime logs
```

### Database connection issues

Verify PostgreSQL is accessible from Docker:

```bash
sudo docker exec insforge-postgrest bash -c '</dev/tcp/10.10.10.10/5432'
```

Check HBA rules allow Docker networks (172.16.0.0/12):

```bash
sudo -iu postgres psql -c "TABLE pg_hba_file_rules;" insforge
```

### PostgREST errors

Verify the database roles exist:

```bash
sudo -iu postgres psql -d insforge -c "SELECT rolname, rolcanlogin FROM pg_roles WHERE rolname IN ('anon','authenticated','project_admin');"
```

### Port conflicts

Check if ports are available:

```bash
ss -tlnp | grep -E '7130|7133|5430'
```
