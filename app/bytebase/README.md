# Bytebase

Bytebase: https://www.bytebase.com/

open-source schema migrator for PostgreSQL (and other databases)

Check public demo: http://ddl.pigsty.io, username: `admin@pigsty.cc`, password: `pigsty`

For HTTPS, use a publicly trusted certificate or install Pigsty's public
`files/pki/ca/ca.crt` in your trust store. Do not bypass certificate validation.

The template follows Bytebase's upstream `latest` image; the 2026-08-27
validation snapshot resolved to `3.21.1`. It uses the external PostgreSQL
connection from `BB_PGURL`. Its health check follows `BB_PORT`; the image's default probe
otherwise checks port 8080 even when the server is configured for another port.


## Get Started

Check [`.env`](.env) file for configurable environment variables:

```bash
BB_PORT=8887
BB_DOMAIN=http://ddl.pigsty
BB_PGURL="postgresql://dbuser_bytebase:DBUser.Bytebase@10.10.10.10:5432/bytebase?sslmode=prefer"
```

Then launch bytebase with:

```bash
make up  # docker compose up
```

Visit [http://ddl.pigsty](http://ddl.pigsty) or http://10.10.10.10:8887

## Makefile

```bash
make up         # launch Bytebase with Docker Compose and external PostgreSQL
make run        # alias for make up
make view       # print bytebase access point
make log        # tail -f bytebase logs
make info       # introspect bytebase with jq
make stop       # stop bytebase container
make clean      # remove bytebase container
make pull       # pull latest bytebase image
make rmi        # remove bytebase image
make save       # save bytebase image to /tmp/docker/bytebase.tgz
make load       # load bytebase image from /tmp/docker/bytebase.tgz
```

## Use External PostgreSQL

This template uses external PostgreSQL for metadata durability. Create the
database and its owning role before starting Bytebase:

```yaml
pg_users: [ { name: dbuser_bytebase ,password: DBUser.Bytebase ,pgbouncer: true ,roles: [ dbrole_admin ]    ,comment: admin user for bytebase database } ]
pg_databases: [ { name: bytebase ,owner: dbuser_bytebase ,revokeconn: true ,comment: bytebase primary database } ]
```

And create business user & database with:

```bash
bin/pgsql-user  pg-meta  dbuser_bytebase
bin/pgsql-db    pg-meta  bytebase
```

Check connectivity:

```bash
psql postgres://dbuser_bytebase:DBUser.Bytebase@10.10.10.10:5432/bytebase
```
