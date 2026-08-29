# PgAdmin4

PGADMIN4: https://www.pgadmin.org/

Tutorial: https://pigsty.io/docs/app/pgadmin

pgAdmin is the most popular and feature rich Open Source administration and development platform for PostgreSQL.

The template follows the untagged `dpage/pgadmin4` image; the 2026-08-27
validation snapshot resolved to `9.17`. Its configuration database and user
files persist in the `pgadmin-data` volume.
The server list and password file are supplied by Pigsty INFRA under
`/infra/pgadmin`; prepare these files before starting this app on a separate node.
Back up `/var/lib/pgadmin` from an existing container before switching to the named
volume, and restore it there if you need to retain its current users and settings.
The native `PGPASS_FILE` loader creates the initial user's `.pgpass`; Pigsty
server definitions use `PassFile: "/.pgpass"`. Regenerate the INFRA files with
the updated `env_pgadmin` templates before upgrading this app. Each PostgreSQL
host/port uses its own configured admin credentials, including libpq escaping
for colons and backslashes. `PGADMIN_SERVER_JSON_FILE` and `PGPASS_FILE` are
absolute container paths; the read-only mounts follow these settings.

`make run` uses the same Compose configuration and persistent volume as
`make up`. The `PGADMIN_DEFAULT_*` settings initialize a new pgAdmin account;
they do not reset the login of an existing account in the persistent volume.

--------

## TL;DR

launch pgadmin4 with:

```bash
cd ~/pigsty; ./app.yml -e app=pgadmin
```

Then visit [http://adm.pigsty](http://adm.pigsty) or http://10.10.10.10:8885 with:

username: `admin@pigsty.cc` and password: `pigsty`



---------

## Reload

Startup imports the server list only on a fresh pgAdmin database. The default
`PGADMIN_REPLACE_SERVERS_ON_STARTUP=False` preserves servers added in the GUI.
Set it to the exact value `True` only when deliberately replacing **all** server
definitions for the configured pgAdmin user; this can remove GUI-added servers.
The upstream image does not recognize lowercase `true` for this setting.
In `apps.pgadmin.conf`, use the quoted string `'True'`, not the YAML boolean
`true`, when opting in to replacement.

The native password-file loader only runs on first initialization. `make up`,
`make start`, and `make restart` refresh the copied `.pgpass` without changing
server definitions. After credential rotation, regenerate the INFRA files and
refresh just the password file:

```bash
./infra.yml -t env_pgadmin                             # regenerate server and password files
./app.yml -e app=pgadmin -t app_launch -e app_args=pass # refresh passwords only
```

When using `docker compose` directly, run `make pass` after startup to refresh
an existing volume's password file. These Make targets read the current host
files, including files atomically replaced by Ansible, rather than a stale
single-file bind mount. They require `jq` on the Docker host.
Once pgAdmin has finished starting, use
`make list` to import additional definitions or `make reload` to import them and
refresh passwords. These imports may add duplicates; replacement is opt-in via
`PGADMIN_REPLACE_SERVERS_ON_STARTUP=True` in `.env` followed by recreation.



--------

## Configure

If you want to change configuration, you can edit [`~/pigsty/app/pgadmin/.env`](.env)

```bash
PGADMIN_DEFAULT_EMAIL=admin@pigsty.cc
PGADMIN_DEFAULT_PASSWORD=pigsty           # IMPORTANT!!! CHANGE PASSWORD
PGADMIN_LISTEN_ADDRESS=0.0.0.0
PGADMIN_PORT=8885
PGADMIN_SERVER_JSON_FILE=/pgadmin4/servers.json
PGPASS_FILE=/pgadmin4/pgpass
PGADMIN_REPLACE_SERVERS_ON_STARTUP=False # True explicitly replaces all user server definitions
```

Or configure them in the `pigsty.yml` config file

```yaml

all:
  children:
    pgadmin:
      hosts: { 10.10.10.10: {} }
      vars:
        app: pgadmin
        apps:
          pgadmin:
            conf:
              PGADMIN_DEFAULT_EMAIL: admin@pigsty.cc   # CHANGE USERNAME
              PGADMIN_DEFAULT_PASSWORD: pigsty         # CHANGE PASSWORD (IMPORTANT!)
              PGADMIN_PORT: 8885

  vars:
    infra_portal:
      pgadmin:
        domain: adm.pigsty                             # CHANGE DOMAIN
        endpoint: "10.10.10.10:8885"                   # CHANGE ENDPOINT
        certbot: adm.pigsty                            # if using real domain & https
```

Then run `app.yml` and `infra.yml` playbook to take effect:

```bash
./app.yml             # install pgadmin according to the config
./infra.yml -t nginx  # re-configure nginx to proxy pgadmin server
```
