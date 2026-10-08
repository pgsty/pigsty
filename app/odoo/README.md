# Odoo

Run Odoo Community `19.0` with Pigsty-managed PostgreSQL 18. This template stays on Odoo 19 for addon compatibility.

Documentation: [English](https://pigsty.io/docs/app/odoo/) | [Chinese](https://pigsty.cc/docs/app/odoo/)

## Get Started

On a fresh supported Linux host:

```bash
curl -fsSL https://repo.pigsty.io/get | bash; cd ~/pigsty
./bootstrap
./configure -c app/odoo
vi pigsty.yml              # Change default passwords
./deploy.yml
./docker.yml
./app.yml                  # Initialize the database, then start Odoo
```

Open `http://<ip>:8069`, or point `odoo.pigsty` to the Nginx host and use the portal. The initial application login is `admin` / `admin`; change the password at first login.

## Configuration

Use [`conf/app/odoo.yml`](https://github.com/pgsty/pigsty/blob/main/conf/app/odoo.yml) for deployment settings. The deployed app is in `/opt/odoo`, with settings in `.env`.

`ODOO_PORT` is the published host port number, defaulting to 8069 on all host interfaces. Compose uses `"${ODOO_PORT}:8069"`; update the Nginx endpoint if you change the port. Use `ODOO_PROXY_MODE=true` with Nginx and `false` for direct access only.

`ODOO_DBNAME` selects one pre-created database; its name must not contain commas. The database manager is disabled. `ODOO_ADMIN_PASSWORD` is the database-management master password, separate from the application login.

For manual deployment, create the PostgreSQL role, database, and `unaccent` / `pg_trgm` extensions before running `make init`, then `make up`. Make helpers require Docker Compose, `jq`, and permission to set directory ownership.

## Odoo Addons

Use Odoo 19 addons and install their dependencies. The default mounts are:

- `/data/odoo/webdata:/var/lib/odoo` for filestore and sessions
- `/data/odoo/addons:/mnt/extra-addons` for addons

Set directory ownership to uid=100, gid=101. Run `make restart` after changing addon code, enable Developer mode, and refresh Apps → Update Apps List to install addons.

The default `workers=0` serves HTTP and WebSocket on 8069. Multiple workers require additional 8072 and `/websocket` routing; see the [Odoo deployment guide](https://www.odoo.com/documentation/19.0/administration/on_premise/deploy.html).

## Updates and Backups

Run `make pull`, then `make up` to update the Odoo 19 image. `make restart` does not apply a new image or environment. Set `ODOO_VERSION` to a published dated 19.0 tag for a fixed version. Major upgrades require database migration and compatible addons.

Use Pigsty/pgBackRest for database backups. Manage filestore and addon backups yourself with Restic or PGFS.
