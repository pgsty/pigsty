# InsForge Integration Report

> InsForge v1.5.0 deployed on Pigsty v4.2.1 Meta node (10.10.10.10)
> Date: 2026-03-11

## Summary

Successfully integrated [InsForge](https://github.com/InsForge/InsForge) into Pigsty's self-hosting app collection.
InsForge is an open-source Backend-as-a-Service (BaaS) platform for AI coding agents, similar to Supabase.

**Architecture**: PostgreSQL managed externally by Pigsty (HA, PITR, monitoring), stateless services in Docker.


## Deliverables

| File | Description |
|------|-------------|
| `conf/app/insforge.yml` | Pigsty config template for one-click InsForge deployment |
| `app/insforge/docker-compose.yml` | Docker Compose with 3 services: insforge, postgrest, deno |
| `app/insforge/.env` | Default environment variables |
| `app/insforge/Makefile` | Standard make targets (up/down/pull/save/load) |
| `app/insforge/README.md` | Self-hosting tutorial and reference |
| `files/insforge.sql` | Database baseline SQL (roles, grants, RLS event triggers) |


## Deployment Test Results

### Services Status

| Service | Image | Port | Status |
|---------|-------|------|--------|
| InsForge App + Dashboard | `ghcr.io/insforge/insforge-oss:v1.5.0` | 7130 | Running (74 MB) |
| PostgREST | `postgrest/postgrest:v12.2.12` | 5430 | Healthy (40 MB) |
| Deno Runtime | `ghcr.io/insforge/deno-runtime:latest` | 7133 | Healthy (37 MB) |

### Functional Tests

| Test | Result |
|------|--------|
| Dashboard login page (HTTP 200) | PASS |
| API health endpoint (`/api/health`) | PASS - v1.5.0 |
| PostgREST schema (30 paths) | PASS |
| Deno runtime health | PASS - Deno 2.0.6, TS 5.6.2 |
| Admin user seeded | PASS - admin@example.com |
| API key generated | PASS |

### Database State

| Item | Details |
|------|---------|
| Schemas | ai, auth, cron, functions, monitor, realtime, schedules, storage, system |
| Extensions | pg_cron 1.6, http 1.7, pgcrypto 1.4, pg_stat_statements 1.12, + 15 more |
| Roles | dbuser_insforge (login), anon, authenticated, project_admin (nologin) |
| Migrations | 21 migrations applied automatically |

### Resource Usage

| Container | CPU | Memory |
|-----------|-----|--------|
| insforge | ~0% idle | 74 MB |
| insforge-postgrest | ~1% idle | 40 MB |
| insforge-deno | ~0% idle | 37 MB |
| **Total** | | **~151 MB** |


## Notes

1. **Port Discovery**: InsForge serves both dashboard UI and API on port **7130** (not 7131 as initially expected). Config templates updated accordingly.

2. **Docker Proxy**: For China region deployments, ghcr.io images require proxy configuration. Added systemd drop-in at `/etc/systemd/system/docker.service.d/http-proxy.conf` to route through host proxy.

3. **pg_cron Requirement**: InsForge requires `pg_cron` in `shared_preload_libraries`, which needs a PostgreSQL restart. Use Patroni REST API PATCH for safe config updates on running clusters.

4. **Database Migrations**: InsForge runs 21 database migrations automatically on first startup, creating schemas: ai, auth, cron, functions, monitor, realtime, schedules, storage, system.

5. **Offline Deployment**: Use `make save` and `make load` for air-gapped environments. Total image size ~1.5 GB compressed.
