# Bytebase

Bytebase: https://www.bytebase.com/

open-source schema migrator for PostgreSQL (and other databases)

Check public demo: http://ddl.pgsty.com, username: `admin@pigsty.cc`, password: `pigsty`

If you want to access bytebase through SSL, you have to trust `files/pki/ca/ca.crt` on your browser (or use the dirty hack `thisisunsafe` in chrome)


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
make up         # pull up bytebase with docker compose in minimal mode
make run        # launch bytebase with docker , local data dir and external PostgreSQL
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

Bytebase use its internal PostgreSQL database by default, You can use external PostgreSQL for higher durability.

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