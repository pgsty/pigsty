# PostgREST

PostgREST: https://postgrest.org/en/stable/index.html

Serve a RESTful API from any Postgres database

The template follows the untagged PostgREST image; the 2026-08-27 validation
snapshot resolved to `v16.2`. Replace `POSTGREST_JWT_SECRET` with a random value
of at least 32 characters.
`make run` is an alias for `make up`; both pass database URIs and JWT secrets
through Compose, including URI query parameters and secrets containing spaces.

This is an example of creating a read-only Pigsty CMDB API with PostgREST.
The default binds only to `127.0.0.1` and connects as `dbuser_view`; do not
expose it publicly without an authenticated reverse proxy. A JWT secret alone
does not force anonymous requests to authenticate.

```bash
cd ~/pigsty/app/postgrest; make up
```

`http://127.0.0.1:8884` is the default endpoint for PostgREST. For a remote
server, use an SSH tunnel or an authenticated Pigsty portal.

## Makefile

```bash
make up         # pull up postgrest with docker compose
make run        # launch postgrest with docker
make ui         # run swagger ui container
make view       # print postgrest access point
make log        # tail -f postgrest logs
make info       # introspect postgrest with jq
make stop       # stop postgrest container
make clean      # remove postgrest container
make rmui       # remove swagger ui container
make pull       # pull the current postgrest image
make rmi        # remove postgrest image
make save       # save postgrest image to /tmp/docker/postgrest.tgz
make load       # load postgrest image from /tmp/docker/postgrest.tgz
```


## Swagger UI

Launch Swagger UI on loopback and visualize the PostgREST API on 8884:

```bash
docker run --init --name swagger -p 127.0.0.1:8883:8080 -e API_URL=http://127.0.0.1:8884 swaggerapi/swagger-ui
```

For remote access, create a local tunnel first:

```bash
ssh -L 8883:127.0.0.1:8883 -L 8884:127.0.0.1:8884 your-server
```

Then visit [http://127.0.0.1:8883/](http://127.0.0.1:8883/).
