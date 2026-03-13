# InsForge

> [InsForge](https://github.com/InsForge/InsForge) -- Open-source Backend-as-a-Service for AI coding agents

Pigsty allows you to self-host **InsForge** with an existing managed HA PostgreSQL cluster, and launch the stateless services with docker-compose.

InsForge is a Supabase-alternative BaaS platform built upon PostgreSQL.
It provides authentication, REST API (PostgREST), edge functions (Deno), real-time subscriptions, and an LLM gateway out of the box.
Design your database schema and frontend, and skip backend development entirely.

Self-hosted InsForge with Pigsty enjoys full PostgreSQL monitoring, IaC, PITR, and high availability,
with the latest PG 17/18 kernels and [460+](https://pgext.cloud/list) PostgreSQL extensions ready to use.


-------

## Quick Start

Download & [install](https://pigsty.io/docs/setup/install) Pigsty with the `insforge` config template:

```bash
curl -fsSL https://repo.pigsty.io/get | bash; cd ~/pigsty
./bootstrap                 # prepare local repo & ansible
./configure -c app/insforge  # use the insforge config template
vi pigsty.yml               # IMPORTANT: CHANGE CREDENTIALS!!
./deploy.yml                # install pigsty & pgsql
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

- **InsForge App** (`ghcr.io/insforge/insforge-oss:v1.5.0`): Main application server with dashboard UI and API (port 7130)
- **PostgREST** (`postgrest/postgrest:v12.2.12`): Auto-generated REST API from PostgreSQL schema (port 5430)
- **Deno Runtime** (`ghcr.io/insforge/deno-runtime:latest`): Serverless edge functions runtime (port 7133)
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
- PostgreSQL cluster `pg-meta` with required users, roles, and database
- Nginx reverse proxy at `isf.pigsty`
- Required extensions: `pgcrypto`, `http`, `pg_cron`

### Key Parameters to Customize

Edit `pigsty.yml` before deploying:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `JWT_SECRET` | `your-secret-key...` | **MUST CHANGE!** JWT signing key (32+ chars) |
| `ADMIN_EMAIL` | `admin@example.com` | Admin login email |
| `ADMIN_PASSWORD` | `pigsty` | Admin login password |
| `POSTGRES_PASSWORD` | `DBUser.Insforge` | Database user password |
| `infra_portal.insforge.domain` | `isf.pigsty` | Nginx domain name |

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
| `project_admin` | No | PostgREST admin with RLS bypass |

### Database

- **Name**: `insforge`
- **Owner**: `dbuser_insforge`
- **Baseline**: `insforge.sql` (grants, default privileges, RLS event triggers)
- **Extensions**: `pgcrypto`, `http`, `pg_cron`

### Shared Libraries

`pg_cron` requires `shared_preload_libraries`:

```yaml
pg_libs: 'pg_cron, pg_stat_statements, auto_explain'
pg_parameters: { cron.database_name: insforge }
```

### HBA Rules

Allow Docker containers to access PostgreSQL:

```yaml
pg_hba_rules:
  - { user: dbuser_insforge, db: all, addr: 172.17.0.0/16, auth: pwd, title: 'allow insforge from docker' }
```


-------

## Docker Services

### Ports

| Service | Port | Description |
|---------|------|-------------|
| InsForge Dashboard + API | 7130 | Main application (dashboard & API) |
| InsForge Auth | 7132 | Authentication service |
| PostgREST | 5430 | REST API auto-generated from schema |
| Deno Runtime | 7133 | Edge functions runtime |

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
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=pigsty

# Database (must match pigsty.yml pg_users)
POSTGRES_HOST=10.10.10.10
POSTGRES_PORT=5432
POSTGRES_DB=insforge
POSTGRES_USER=dbuser_insforge
POSTGRES_PASSWORD=DBUser.Insforge

# Optional: LLM Gateway
OPENROUTER_API_KEY=

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

Check HBA rules allow Docker network (172.17.0.0/16):

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
ss -tlnp | grep -E '7130|7131|7132|7133|5430'
```
