# metabase

The template defaults to `metabase/metabase:v0.64.1.x`, the official OSS image
for Metabase 64.1. `METABASE_IMAGE` can override that reference for a controlled
upgrade or rollback. The application metadata uses its own `metabase` database
and `dbuser_metabase` role; it must not share the Pigsty CMDB database. Provision
both before starting the container.

Metabase 63 to 64 automatically migrates the application database. Before an
existing deployment is updated, back up that database and record the running
image digest, then test the upgrade on a restored copy. Keep the old image and
matching database backup together: swapping the image alone is not a database
rollback. The official Docker image includes Java 25; no host Java upgrade is
needed. Deployments using custom visualizations must update to SDK v2; review
changed Metabot variables and action prefill requests only if those features
are used.

See the [64.1 release notes](https://www.metabase.com/changelog/64#metabase-641)
and [upgrade guide](https://www.metabase.com/docs/latest/installation-and-operation/upgrading-metabase).
The health check waits for `/api/health`, which checks both Metabase and its
application database. Initial schema migrations can take a while; wait for
`docker compose ps` to report healthy before opening the setup wizard.

Fast analytics with the friendly UX and integrated tooling to let your company explore data on their own: https://metabase.com/

```bash
# do not forget to check app/metabase/.env before make up
cd app/metabase; make up
```


```bash
make up         # pull up metabase with docker compose
make run        # launch metabase with docker, local data dir and external PostgreSQL
make view       # print metabase access point
make log        # tail -f metabase logs
make info       # introspect metabase with jq
make stop       # stop metabase container
make clean      # remove metabase container
make pull       # pull the configured Metabase image
make rmi        # remove metabase image
make save       # save metabase image to /tmp/docker/metabase.tgz
make load       # load metabase image from /tmp/docker/metabase.tgz
```



## Expose Service

Expose metabase UI with pigsty's Nginx via `infra_portal`:

```yaml
infra_portal:                     # infra services exposed via portal
  home : { domain: i.pigsty }     # default domain name
  # ADD METABASE ENTRY HERE, then apply with (./infra.yml -t nginx)
  metabase     : { domain: mtbs.pigsty ,endpoint: "10.10.10.10:9004", websocket: true }
```

Visit [http://mtbs.pigsty](http://mtbs.pigsty) or http://10.10.10.10:9004 with:




## Docker Compose 

```yaml

services:
  metabase:
    container_name: metabase
    image: ${METABASE_IMAGE:-metabase/metabase:v0.64.1.x}
    environment:
      MB_DB_TYPE: "${MB_DB_TYPE}"
      MB_DB_DBNAME: "${MB_DB_DBNAME}"
      MB_DB_PORT: "${MB_DB_PORT}"
      MB_DB_USER: "${MB_DB_USER}"
      MB_DB_PASS: "${MB_DB_PASS}"
      MB_DB_HOST: "${MB_DB_HOST}"
    restart: always
    ports:
      - "${MB_PORT}:3000"
    healthcheck:
      test: ["CMD", "curl", "--fail", "--silent", "http://127.0.0.1:3000/api/health"]
      interval: 15s
      timeout: 5s
      retries: 10
      start_period: 60s

```
