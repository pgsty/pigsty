# PgAdmin4

PGADMIN4: https://www.pgadmin.org/

Tutorial: https://doc.pgsty.com/software/pgadmin/

pgAdmin is the most popular and feature rich Open Source administration and development platform for PostgreSQL.

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

To reload server list, just re-generate `servers.json` file and restart pgadmin

```bash
./infra.yml -t env_pgadmin                                # regenerate pgadmin server list
./app.yml -e app=pgadmin -t app_launch -e app_args=reload # reload pgadmin server list
```

> PgAdmin launch is slow, may take 30+ seconds to start, please reload after server started. 



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
PGADMIN_REPLACE_SERVERS_ON_STARTUP=true
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
