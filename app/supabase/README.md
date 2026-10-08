# Supabase

> [Supabase](https://supabase.com/) —— Build in a weekend, Scale to millions

Pigsty allow you to self-host **supabase** with existing managed HA postgres cluster, and launch the stateless part of supabase with docker-compose.
Check the official tutorial for details: [Self-Hosting Supabase](https://pigsty.io/docs/app/supabase)

This template tracks the official
[`self-hosted/v0.8.2` release](https://github.com/supabase/supabase/tree/564eab8ad7840b13324f68b1bfac074ef8d51c21/docker)
(commit `564eab8ad7840b13324f68b1bfac074ef8d51c21`). Envoy `1.39.1`
is the default API gateway and Studio is pinned to
`2026.09.07-sha-7996410`; PostgreSQL remains external and managed by Pigsty.
Kong `3.9.3` is retained only as an optional transition fallback:

```bash
docker compose -f docker-compose.yml -f docker-compose.kong.yml up -d
```

Supabase is the open-source Firebase alternative built upon PostgreSQL.
It provides authentication, API, edge functions, real-time subscriptions, object storage, and vector embedding capabilities out of the box.
All you need to do is to design the database schema and frontend, and you can quickly get things done without worrying about the backend development.

Supabase's slogan is: "**Build in a weekend, Scale to millions**". Supabase has great cost-effectiveness in small scales (4c8g) indeed.
But there is no doubt that when you really grow to millions of users, some may choose to self-hosting their own Supabase —— for functionality, performance, cost, and other reasons.

That's where Pigsty comes in. Pigsty provides a complete one-click self-hosting solution for Supabase.
Self-hosted Supabase can enjoy full PostgreSQL monitoring, IaC, PITR, and high availability, the new PG 18 kernels (and 15~18),
and [575](https://pigsty.io/ext/list) PostgreSQL extensions ready to use, and can take full advantage of the performance and cost advantages of modern hardware.



-------

## Quick Start

First, download & [install](https://pigsty.io/docs/setup/install) pigsty as usual, with the `supabase` config template:

```bash
 curl -fsSL https://repo.pigsty.io/get | bash
 cd pigsty
./configure -c supabase  # use the supabase config template (IMPORTANT: CHANGE PASSWORDS!)
./deploy.yml             # install Pigsty, create HA PostgreSQL and Silo clusters
```

Please change the `pigsty.yml` config file according to your need before deploying Supabase. (Credentials)
Make sure `API_EXTERNAL_URL` points to the Auth endpoint with the `/auth/v1` suffix, for example `https://supa.pigsty/auth/v1`.
The default PostgREST schema list is `public,graphql_public`; the `storage` schema is used by the Storage API and is not exposed through PostgREST by default.
Analytics data is stored in the internal `_supabase` database under the `_analytics` schema, controlled by `LOGFLARE_DB` and `LOGFLARE_SCHEMA`.
Supabase Studio Query Performance is supported through `extensions.pg_stat_statements` compatibility wrappers while Pigsty keeps the actual `pg_stat_statements` extension in the `monitor` schema for pg_exporter.
To enable asymmetric auth, set `JWT_KEYS`, `JWT_JWKS`, and all four
opaque/asymmetric API-key variables together, then enable the verification
override (leaving it disabled preserves legacy HS256 mode):

```bash
docker compose -f docker-compose.yml -f docker-compose.asymmetric.yml up -d
```

Edge Functions always receive `SUPABASE_JWKS` from `JWT_JWKS` and fall back to
legacy HS256 verification when it is empty.
The worker and shared `volumes/functions/deno.jsonc` import map are updated
together, including `@supabase/functions-js`, `@supabase/server`, and the
per-request function slug. See [source provenance](volumes/functions/SOURCE.md).

Both gateways restrict `/pg/` metadata CORS to `SUPABASE_PUBLIC_URL` and local
development origins, removing wildcard headers emitted by postgres-meta. This
does not replace the administrator API key requirement.

Gateway templates serialize environment values as YAML and Lua string literals,
so dashboard credentials retain quotes, backslashes, ampersands, and Unicode.
Dashboard usernames must still follow HTTP Basic authentication constraints:
no colon or line breaks. Keep normal Compose quoting when editing `.env`.

`bin/dump` / `bin/load` use standard Docker image archives, including imgproxy,
so image metadata is preserved. Transfer complete files and verify checksums
before loading; Docker 29.7.2 on ARM64 was tested with this workflow.

The complete offline bundle deliberately includes **both** Envoy and Kong.
Run `make pull` before `make save`, even when only one gateway is deployed;
the pull target fetches both independently of `COMPOSE_FILE`. Dump/load check
the complete image/archive set before starting, so a missing optional gateway
does not leave a partially written bundle. Regenerate old rootfs-only imgproxy
archives with the current helper instead of mixing archive formats.

Then, run the [`docker.yml`](https://github.com/pgsty/pigsty/blob/main/docker.yml) and [`app.yml`](https://github.com/pgsty/pigsty/blob/main/app.yml) to install supabase with docker.

```bash
./docker.yml   # install docker & docker compose
./app.yml      # launch supabase stateless part with docker compose
```

You can access the supabase API / Web UI through the `80/443` infra portal,
with configured DNS for public domain, or a local `/etc/hosts` record with `supa.pigsty` pointing to the node also works.

> Default username & password: `supabase` : `pigsty`

> Beware the storage API requires Silo/S3 to work, and you have to access it via a valid domain name (`/etc/hosts` or real domain).

## Existing deployments

Back up PostgreSQL, object storage, and application volumes before upgrading.
The old template used a Compose service named `kong`; this release calls the
gateway `api-gw`. Before replacing the old Compose files, run `docker compose
down` with the **old** configuration, without `-v`. This stops the old gateway
and releases ports 8000/8443 while preserving named volumes and the external
Pigsty databases/S3 data. Then update the files and start the new stack. Merely
running the new `up -d` leaves the old `kong` service as an orphan and can cause
port/container-name conflicts. Review any locally added services first; do not
indiscriminately remove orphans.

`files/supabase.sql` is a fresh-install baseline, not a replayable upgrade script.
Updating containers does not apply its new SQL grants or clear settings from an
existing database. Version `0.8.2` removes the SQL-visible
`app.settings.jwt_secret` and `PGRST_APP_SETTINGS_JWT_SECRET` settings; JWT
verification remains configured by the application-level variables, and
`app.settings.jwt_exp` remains available.

Before this change, review custom SQL functions that depend on
`current_setting('app.settings.jwt_secret')`. If they still need a signing
secret, migrate them to a restricted Vault secret as described in
[upstream PR #45003](https://github.com/supabase/supabase/pull/45003), with access
limited to the function owner and no public RPC exposing the decrypted value.
Do not copy the secret into SQL-visible settings again.

After reviewing those dependencies and backing up the target database, run from
the Pigsty installation root with an administrator connection to apply the narrow, idempotent
[`files/supabase-0.8.2.sql`](../../files/supabase-0.8.2.sql) upgrade. It resets the
old database-level secret and grants `extensions` schema USAGE to the webhook
owner `supabase_functions_admin`, preserving JWT expiration and existing data:

```bash
psql -X -v ON_ERROR_STOP=1 -d '<target-supabase-database>' -f files/supabase-0.8.2.sql
```

Remove the old database parameter from your deployment inventory as well as
updating Compose. The script only resets the database-level setting used by the
old template. If you added the secret through `ALTER ROLE`, a server setting, or
custom session SQL, review and remove those separate sources too. Recreate
PostgREST with the new Compose configuration, and reconnect clients; existing
sessions can retain the old value. Verify in a new session as an ordinary
application role, without printing any secret:

```sql
SELECT nullif(current_setting('app.settings.jwt_secret', true), '') IS NULL
       AS jwt_secret_removed;
SELECT has_schema_privilege('supabase_functions_admin', 'extensions', 'USAGE')
       AS webhook_extensions_usage;
```

For older deployments, also check the Storage role's prerequisite in the target
Supabase database:

```sql
SELECT current_database(),
       has_database_privilege('supabase_storage_admin', current_database(), 'CREATE');
-- If missing, apply as the database administrator; replace postgres if renamed.
GRANT CREATE ON DATABASE postgres TO supabase_storage_admin;
```

Review and apply the upstream
[2026-07-30 pg_cron privilege migration](https://github.com/supabase/postgres/blob/develop/migrations/db/migrations/20260730000000_revoke_trigger_on_cron_tables_from_postgres.sql)
separately if the existing database does not contain it, preserving local
customizations. Never replay the entire baseline over an existing installation.
Fresh-install and same-version recreation tests do not replace a rehearsal of
your existing database's version-specific upgrade path.
