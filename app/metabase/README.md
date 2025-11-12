# metabase

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
make pull       # pull latest metabase image
make rmi        # remove metabase image
make save       # save metabase image to /tmp/metabase.tgz
make load       # load metabase image from /tmp
```



## Expose Service

Expose metabase UI with pigsty's Nginx via `infra_portal`:

```yaml
infra_portal:                     # domain names and upstream servers
  home         : { domain: h.pigsty }
  grafana      : { domain: g.pigsty ,endpoint: "${admin_ip}:3000" , websocket: true }
  prometheus   : { domain: p.pigsty ,endpoint: "${admin_ip}:9058" }
  alertmanager : { domain: a.pigsty ,endpoint: "${admin_ip}:9059" }
  blackbox     : { endpoint: "${admin_ip}:9115" }
  loki         : { endpoint: "${admin_ip}:3100" }
  # ADD METABASE ENTRY HERE, then apply with (./infra.yml -t nginx)
  metabase     : { domain: mtbs.pigsty ,endpoint: "10.10.10.10:9004", websocket: true }
```

Visit [http://mtbs.pigsty](http://mtbs.pigsty) or http://10.10.10.10:9004 with:




## Docker Compose 

```yaml

services:
  metabase:
    container_name: metabase
    image: metabase/metabase:latest
    environment:
      MB_DB_TYPE: "${MB_DB_TYPE}"
      MB_DB_DBNAME: "${MB_DB_DBNAME}"
      MB_DB_PORT: "${MB_DB_PORT}"
      MB_DB_USER: "${MB_DB_USER}"
      MB_DB_PASS: "${MB_DB_PASS}"
      MB_DB_HOST: "${MB_DB_HOST}"
    restart: always
    ports:
      - ${MB_PORT}:8080

```
