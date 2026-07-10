# electric

[Electric](https://electric-sql.com/), Sync Solved, sync postgres shape to frontend

> Electric is a Postgres sync engine. It solves the hard problems of sync for you, including[ partial replication](https://electric-sql.com/docs/guides/shapes), [fan-out](https://electric-sql.com/docs/api/http#caching), and [data delivery](https://electric-sql.com/docs/api/http).

Review `.env`, then launch the service:

```bash
cd ~/pigsty/app/electric
make up
make view
```

The HTTP API and Prometheus endpoint use ports `8002` and `8003` by default.
The database user in `DATABASE_URL` needs replication privileges.

> The example defaults to `ELECTRIC_INSECURE=true`, which leaves shape requests
> unauthenticated. Keep it only for trusted development networks. For a real
> deployment, disable insecure mode and configure `ELECTRIC_SECRET` before
> exposing the service.

The current Compose file does not mount Electric's optional file-backed state.
PostgreSQL is the durable source and must be covered by the normal backup plan;
review Electric's storage settings before relying on local shape persistence.
