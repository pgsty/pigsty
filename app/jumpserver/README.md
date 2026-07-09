# JumpServer

[JumpServer](https://www.jumpserver.com/) is an open-source PAM / bastion host.
This Pigsty app runs the JumpServer community stack with Docker Compose and uses
Pigsty-managed PostgreSQL as the durable backend database.

Full documentation: <https://pigsty.io/docs/app/jumpserver>

## Quick Start

```bash
./configure -c app/jumpserver
vi pigsty.yml                 # change passwords, secrets, IPs, and domains
./deploy.yml                  # install Pigsty and PostgreSQL
./docker.yml                  # install Docker
./app.yml                     # install JumpServer
```

After the containers are up, run the JumpServer database migration:

```bash
cd /opt/jumpserver
make migrate
make health
```

## Access

Default endpoints:

```text
http://jump.pigsty
http://10.10.10.10:8080
ssh -p 2222 admin@10.10.10.10
```

Default login:

```text
admin / ChangeMe
```

Change the password after the first login.

JumpServer checks trusted domains during login. Make sure `DOMAINS` contains the
hostnames or IPs used by browsers:

```ini
DOMAINS=10.10.10.10:8080,10.10.10.10,jump.pigsty
```

Use the normal login URL:

```text
http://10.10.10.10:8080/core/auth/login/?admin=1
```

Do not validate with an old `csrf_failure=1` URL; that page can show a
configuration warning from the failed request context.

## Configuration

`app.yml` copies this directory to `/opt/jumpserver` and renders
`/opt/jumpserver/.env` from `apps.jumpserver.conf`.

Key settings:

```ini
JUMPSERVER_VERSION=v4.10.16-ce
JUMPSERVER_DATA=/data/jumpserver
DOMAINS=10.10.10.10:8080,10.10.10.10,jump.pigsty

DB_HOST=10.10.10.10
DB_PORT=5432
DB_USER=jumpserver
DB_PASSWORD=DBUser.JumpServer
DB_NAME=jumpserver

DOCKER_SUBNET=192.168.250.0/24
REDIS_IP=192.168.250.2
CORE_IP=192.168.250.4
REDIS_HOST=192.168.250.2
CORE_HOST=http://192.168.250.4:8080

HTTP_PORT=8080
SSH_PORT=2222
CORE_WORKER=2
CELERY_WORKER_COUNT=2
```

Do not set `DB_HOST=127.0.0.1`; inside a container that means the container
itself. Use the host intranet IP or a Pigsty L2 VIP.

The app uses a fixed Docker bridge subnet and static container IPs to avoid
Docker DNS races during JumpServer component startup. PostgreSQL HBA must allow
the app bridge subnet, by default `192.168.250.0/24`.

## Operations

Run under `/opt/jumpserver`:

```bash
make up        # start containers
make down      # stop containers
make restart   # restart containers
make status    # show container status
make log       # follow logs
make health    # check HTTP/DB/Redis health
make migrate   # run ./jms upgrade_db
make exec      # enter the core container
```

## PostgreSQL

JumpServer 4.x requires PostgreSQL 16 or newer. The app database does not require
extra PostgreSQL extensions.

Use direct PostgreSQL on `5432` by default. PgBouncer is acceptable only with
session pooling for the `jumpserver` user; do not use transaction pooling for
Django migrations or Celery Beat.

## Backup

Back up both layers:

- PostgreSQL: Pigsty pgBackRest / PITR for the `jumpserver` database.
- Application state: `/opt/jumpserver/.env` and `/data/jumpserver`.

`SECRET_KEY` and `BOOTSTRAP_TOKEN` must be generated once and preserved. Losing
the original `SECRET_KEY` can make encrypted account secrets unrecoverable.
