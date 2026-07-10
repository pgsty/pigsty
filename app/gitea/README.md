# gitea

Gitea - Git with a cup of tea : https://gitea.io/

A painless self-hosted Git service.

Gitea is a community managed lightweight code hosting solution written in Go. It is published under the MIT license.

Check public demo on pigsty: http://git.pigsty.cc, you can register a new user and explore it yourself.

## Get Started

Check [`.env`](.env) file for configurable environment variables:

```bash
# server
GITEA_PORT=8889
GITEA_SSH_PORT=222
GITEA_DATA=/data/gitea
GITEA_DOMAIN=http://git.pigsty

# database
GITEA_DB_TYPE=postgres
GITEA_DB_USER=dbuser_gitea
GITEA_DB_PASSWORD=DBUser.Gitea
GITEA_DB_HOST=10.10.10.10:5432
GITEA_DB_NAME=gitea
GITEA_DB_SSLMODE=disable
```

Then launch gitea with `docker compose`:

```bash
cd app/gitea; make up
```

Visit [http://git.pigsty](http://git.pigsty) or http://10.10.10.10:8889 and follow the installation wizard.

## Makefile

```bash
make up      # pull up gitea with docker compose in minimal mode
make view    # print gitea access point
make log     # tail -f gitea logs
make info    # introspect gitea with jq
make stop    # stop gitea container
make clean   # remove gitea container
make rmdata  # remove gitea data: /data/gitea
make pull    # pull latest gitea image
make rmi     # remove gitea image
make save    # save gitea image to /tmp/docker/gitea.tgz
make load    # load gitea image from /tmp/docker/gitea.tgz
```

## Use External PostgreSQL

gitea use its internal sqlite database by default, You can use external PostgreSQL for higher durability.

```yaml
# postgres://dbuser_gitea:DBUser.gitea@10.10.10.10:5432/gitea
pg_users: [ { name: dbuser_gitea    ,password: DBUser.Gitea    ,pgbouncer: true ,roles: [ dbrole_admin ]    ,comment: admin user for gitea service } ]
pg_databases: [ { name: gitea    ,owner: dbuser_gitea    ,revokeconn: true ,comment: gitea meta database } ]
```

```bash
bin/pgsql-user pg-meta dbuser_gitea
bin/pgsql-db   pg-meta gitea
```

## Expose Service

Add `gitea` entry to `infra_portal` to expose gitea service with nginx.

```yaml
infra_portal:                     # domain names and upstream servers
  gitea : { domain: git.pigsty  ,endpoint: "127.0.0.1:8889"   }
```
