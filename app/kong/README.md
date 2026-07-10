# Kong

Kong the API Gateway: https://konghq.com/

Build delightful customer experiences and unleash developer productivity with Kong, the fastest cloud native API
platform.

## TL;DR

Check [`.env`](.env) for postgres credentials and ports:

```bash
#https://hub.docker.com/_/kong
KONG_DATABASE=postgres
KONG_PG_HOST=10.10.10.10
KONG_PG_USER=dbuser_kong
KONG_PG_DATABASE=kong
KONG_PG_PASSWORD=DBUser.Kong
KONG_PORT=8000
KONG_PORT_SSL=8443
KONG_ADMIN_PORT=8001
```

Bootstrap a new, empty Kong database once, then launch Kong:

```bash
cd app/kong
make bootstrap   # only for a fresh database; this is not an upgrade command
make up
```


## Makefile

```bash
make up         # pull up kong with docker compose
make bootstrap  # initialize a new, empty Kong database once
make ui         # run swagger ui container
make log        # tail -f kong logs
make info       # introspect kong with jq
make stop       # stop kong container
make clean      # remove kong container
make rmui       # remove swagger ui container
make pull       # pull latest kong image
make rmi        # remove kong image
make save       # save kong image to /tmp/docker/kong.tgz
make load       # load kong image from /tmp/docker/kong.tgz
```

## Scripts

* Default Port: 8000
* Default SSL Port: 8443
* Default Admin Port: 8001
* Default Postgres Database: `postgres://dbuser_kong:DBUser.Kong@10.10.10.10:5432/kong`

```yaml
# postgres://dbuser_kong:DBUser.Kong@10.10.10.10:5432/kong
- { name: kong, owner: dbuser_kong, revokeconn: true , comment: kong the api gateway database }
- { name: dbuser_kong, password: DBUser.Kong , pgbouncer: true , roles: [ dbrole_admin ] }
```
