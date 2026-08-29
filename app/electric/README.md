# electric

[Electric](https://electric-sql.com/), Sync Solved, sync postgres shape to frontend

This template follows Electric's untagged upstream image. The 2026-08-27
validation snapshot resolved to sync-service `1.7.12`, which includes the secure
mode path-normalization authentication fix released on 2026-08-21. Pin an image
explicitly only when an installation needs a controlled upgrade window.

> Electric is a Postgres sync engine. It solves the hard problems of sync for you, including[ partial replication](https://electric-sql.com/docs/guides/shapes), [fan-out](https://electric-sql.com/docs/api/http#caching), and [data delivery](https://electric-sql.com/docs/api/http).

Review `.env`, then launch the service:

```bash
cd ~/pigsty/app/electric
make up
make view
```

The HTTP API uses port `8002` by default.
The database user in `DATABASE_URL` needs replication privileges.

> The example defaults to `ELECTRIC_INSECURE=true`, which leaves shape requests
> unauthenticated. Keep it only for trusted development networks. For a real
> deployment, disable insecure mode and configure `ELECTRIC_SECRET` before
> exposing the service.

Shape metadata and logs are persisted in the `electric-data` volume at
`ELECTRIC_STORAGE_DIR` (default `/var/lib/electric`, an absolute container path).
The volume mount follows this setting when it is changed. PostgreSQL remains
the durable source and must be covered
by the normal backup plan. Losing the Electric volume does not lose database
data, but clients may receive `409` and need a full shape refetch.

The 1.7.12 validation snapshot showed that same-version container recreation on
an unchanged PostgreSQL timeline
verified to retain the shape handle and rows, including when the volume's mount
path changes. A PostgreSQL identity or timeline change is different: that
version [invalidates cached shapes](https://github.com/electric-sql/electric/blob/%40core%2Fsync-service%401.7.12/packages/sync-service/lib/electric/connection/manager.ex#L421-L465).
Clients must handle `409` / [`must-refetch`](https://electric.ax/docs/sync/api/http#control-messages)
by discarding their local shape cache and syncing again. This does not imply
loss of the PostgreSQL source data; an ordinary database restart does not
necessarily change its timeline.

Prometheus is disabled by default. Do not set `ELECTRIC_PROMETHEUS_PORT` unless
the endpoint is periodically scraped: Electric warns that an enabled but
unscraped reporter can retain metrics until memory is exhausted.
