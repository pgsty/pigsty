# JumpServer

[JumpServer](https://www.jumpserver.com/) is an open-source PAM / bastion host.
This Pigsty app runs the JumpServer community stack with Docker Compose and uses
Pigsty-managed PostgreSQL as the durable backend database.

Full documentation: https://pigsty.io/docs/app/jumpserver

This template follows the [official v5.1.1 CE installer](https://github.com/jumpserver/installer/tree/83facb768be7b60e7d38d498ed24214538899c67), checked on 2026-11-06. Core, Celery, KoKo, Chen, Kael, and Web use the same `v5.1.1-ce` release. There is no separate Lion container in 5.x. The default image namespace is the official Aliyun mirror. On 2026-11-06 both the Aliyun mirror and Docker Hub (`IMAGE_PULL_PREFIX=docker.io/jumpserver`) served all five `v5.1.1-ce` tags; the two registries publish separate builds with different digests.

The selected application images are `linux/amd64`; ARM64 is not validated. Allow at least 4 CPUs, 8 GB RAM, and 100 GB disk. JumpServer is GPLv3; this Pigsty template is Apache-2.0.

## Quick Start

```bash
./configure -c app/jumpserver
vi pigsty.yml                 # change passwords, secrets, IPs, and domains
./deploy.yml                  # install Pigsty and PostgreSQL
./docker.yml                  # install Docker
./app.yml                     # install JumpServer
```

The one-shot `init` service runs database migrations, then uses a separate
Django process to initialize a missing terminal host key and validate it. It
never replaces an existing key. Core starts only after initialization succeeds;
Celery and the terminal components then wait for Core's health. This avoids
Core caching empty settings on a fresh database and KoKo failing with
`Parse Terminal private key failed`. Check readiness with:

```bash
cd /opt/jumpserver
make health
```

`jms_init` exiting with code 0 is expected; the other seven containers should
be healthy. An initialization failure blocks Core instead of silently starting
a partially configured stack.

`make restart` stops the stack and brings it up through the same initialization
gate. Do not use an unrestricted `docker compose restart`: that command restarts
the one-shot initializer and Core in parallel without waiting for initialization
to succeed. Redis also follows `REDIS_PORT`; its readiness check requires an
authenticated `PONG`, not just a zero `redis-cli` exit code.

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
IMAGE_PULL_PREFIX=registry.cn-beijing.aliyuncs.com/jumpservice
JUMPSERVER_VERSION=v5.1.1-ce
REDIS_VERSION=7.4.12-bookworm
JUMPSERVER_DATA=/data/jumpserver
DOMAINS=10.10.10.10:8080,10.10.10.10,jump.pigsty
WS_ALLOWED_ORIGINS=http://10.10.10.10:8080,http://10.10.10.10,http://jump.pigsty,https://jump.pigsty

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
KOKO_WEB_PROXY_PORT=5001
KOKO_PRIVILEGED=true
WEB_PROXY_ALLOWED_HOSTS=localhost,127.0.0.1
ANSIBLE_DOCKER_ENABLED=false
CORE_WORKER=2
CELERY_WORKER_COUNT=2
```

Do not set `DB_HOST=127.0.0.1`; inside a container that means the container
itself. Use the host intranet IP or a Pigsty L2 VIP.

The app uses a fixed Docker bridge subnet and static container IPs to avoid
Docker DNS races during JumpServer component startup. PostgreSQL HBA must allow
the app bridge subnet, by default `192.168.250.0/24`.
If you change `DOCKER_SUBNET`, update all component `*_IP` values, including
`INIT_IP` (the one-shot initializer uses `192.168.250.9` by default).

Since 5.1.0, Core rejects browser WebSocket connections (task logs, site messages, system tools, LDAP) whose `Origin` is not allowed. Without `WS_ALLOWED_ORIGINS`, Core derives the list from `SITE_URL` and `DOMAINS`; with the default loopback `SITE_URL`, scheme-less public `DOMAINS` entries only allow `https://` Origins. `WS_ALLOWED_ORIGINS` therefore lists every browser origin explicitly, including plain-HTTP ones. Keep it in sync with `DOMAINS`, use comma-separated `scheme://host[:port]` values without paths or wildcards, and never set it to an empty value: Core fails to start on an invalid list.

Kael 5.1 forwards the user's Core session instead of signing delegation tokens, so 5.1 no longer uses `CHAT_AI_DELEGATION_SECRET`.

`HTTP_PORT` changes the published host port only. The official Web image always
listens on port `80` inside the container.

`WEB_PROXY_ALLOWED_HOSTS` allows Website asset target hosts. Add the hostnames or IPs of those assets while retaining `localhost,127.0.0.1` for KoKo's session-control API. Set the JumpServer Endpoint's Web proxy port to match `KOKO_WEB_PROXY_PORT`.

## Operations

Run under `/opt/jumpserver`:

```bash
make up        # start containers
make down      # stop containers
make restart   # restart containers
make status    # show container status
make log       # follow logs
make health    # check HTTP/DB/Redis health
make migrate   # ordered stop / init / start, same as restart (brief outage)
make exec      # enter the core container
```

Job Center is disabled by default upstream. If you enable it under System Settings → Feature Settings, keep Ansible Docker Isolation disabled for this template. `ANSIBLE_DOCKER_ENABLED=false` uses in-container execution; host Docker isolation requires a separate executor image, host socket access, and upstream host paths. Celery runs without full privileged mode. `KOKO_PRIVILEGED=true` preserves the upstream default for the expanded KoKo component; the SSH path was also tested with it disabled. RDP/VNC privilege requirements were not validated.

## PostgreSQL

JumpServer 5.x requires PostgreSQL 16 or newer. The app database does not require
extra PostgreSQL extensions. The external database path was tested with PostgreSQL 18.6 using a non-superuser application role.

Use direct PostgreSQL on `5432` by default. PgBouncer is acceptable only with
session pooling for the `jumpserver` user; do not use transaction pooling for
Django migrations or Celery Beat.

## Backup

Back up both layers:

- PostgreSQL: Pigsty pgBackRest / PITR for the `jumpserver` database.
- Application state: `/opt/jumpserver/.env` and `/data/jumpserver`.

`SECRET_KEY` and `BOOTSTRAP_TOKEN` must be generated once and preserved. Losing
the original `SECRET_KEY` can make encrypted account secrets unrecoverable.

## Upgrade from 5.0.0 to 5.1.1

The official installer changed no PostgreSQL-related setting between v5.0.0 and v5.1.1. Pigsty-relevant changes are the version bump, the removal of the Kael delegation key, Redis `7.4.12-bookworm`, and the WebSocket Origin check described above. This path has not yet been run end to end.

1. Back up the database, the entire `/opt/jumpserver` directory, and `/data/jumpserver` together, as for a major upgrade.
2. Update the full Compose file and `.env` (or `apps.jumpserver.conf` in `pigsty.yml`). Keep the original `SECRET_KEY`, `BOOTSTRAP_TOKEN`, database and Redis passwords. Add `WS_ALLOWED_ORIGINS` with every origin browsers use. `CHAT_AI_DELEGATION_SECRET` is no longer used and can be removed.
3. Use `make pull`, then `make restart`. Init migrates first; inspect its log and verify `Exited (0)` plus seven healthy services.
4. Verify old logins, credentials, the host-key fingerprint, real sessions, historical replay, a task log or job output in the browser, and the Kael assistant.

After 5.1 migrations, rollback requires restoring the pre-upgrade database, files, and keys.

## Upgrade from 4.10.19 to 5.0.0

The [pinned official upgrade script](https://github.com/jumpserver/installer/blob/33785347d95677ad87c0cc2f754d4f671b4e086f/scripts/7_upgrade.sh) accepts source versions from v3.10.11. The tested Pigsty path is `v4.10.19-ce → v5.0.0-ce`, with no intermediate version. These steps use the v5.0.0 template files; continue with the 5.0.0 → 5.1.1 steps afterwards.

1. Stop the old stack during maintenance. Back up the database, the entire `/opt/jumpserver` directory, and `/data/jumpserver` together. Prove recovery in a separate database and directory.
2. Update the full Compose file, `init.sh`, Makefile, and `.env`. Keep the original `SECRET_KEY`, `BOOTSTRAP_TOKEN`, database and Redis passwords. Add a random `CHAT_AI_DELEGATION_SECRET`.
3. Replace `LION_IP` with `KAEL_IP` and create the Kael data directory. Stop the old Lion container and remove it or disconnect its network if needed to release the fixed IP. Preserve old data and backups.
4. Use `make pull`, then `make up`. Init migrates first; inspect its log and verify `Exited (0)` plus seven healthy services.
5. Verify old logins, assets, permissions, decrypted credentials, the host-key fingerprint, real sessions, and historical replay.

If a migration fails, preserve logs, fix the cause, and retry. After 5.x migrations, rollback requires restoring the pre-upgrade database, files, and original keys; changing image tags back is insufficient. To restore, use the full Compose version corresponding to the backup and start through init.

## Validation scope

The runtime tests below were run against `v5.0.0-ce`. For `v5.1.1-ce`, only the Compose rendering and the image manifests on both registries have been checked so far.

The M3 tests cover fresh 5.x installation, an actual 4.10.19 backup/restore, and an in-place 4.10.19 → 5.0.0 upgrade, all using isolated external PostgreSQL 18 databases. API/form login, user/asset/account/permission operations, negative authorization, SSH, terminal WebSockets, command auditing, and recording downloads are verified. Browser-based Chen queries against a PostgreSQL 18.6 asset return version `180006` and synthetic value `42`; a real Ansible safe-command job succeeds without privileged containers. Kael authentication, conversation/message persistence, and permission isolation are checked without an LLM provider. Ordinary conversation history resides in the Core database; Terminal AI state resides in Kael data files. Upstream discards empty conversation drafts on restart.

RDP/VNC, native clients, ARM64, enterprise components, and external-model inference are outside this validation. Container health is only the first readiness check.
