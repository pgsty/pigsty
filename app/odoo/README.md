# Odoo

[Odoo](https://www.odoo.com/), Open Source ERP.

> All your business on one platform, Simple, efficient, yet affordable

Odoo pigsty installation tutorial: [Self-hosting Odoo](https://pigsty.io/docs/app/odoo)

Check public demo: http://odoo.pigsty.cc, username: `test@pigsty.cc`, password: `pigsty`

The template follows the Odoo `19.0` major-version channel; the validation
snapshot resolved to `19.0-20260817`. Change `ODOO_ADMIN_PASSWORD` before
deployment; it protects Odoo's database-management
operations and is separate from the first application's administrator login.
The fresh database's application login is `admin` / `admin`; change it at first login.
It is passed as `ODOO_ADMIN_PASSWD`, the native Odoo 19 environment setting;
`--admin-passwd` is not a supported command-line option.
Database credentials also use the image's native `PGHOST`, `PGPORT`, `PGUSER`,
and `PGPASSWORD` support, so the entrypoint does not append the password to
the Odoo process's command line.


--------

## Get Started

First, follow the standard pigsty single (or multiple if you want) node installation, using the [`conf/app/odoo`](https://github.com/pgsty/pigsty/blob/main/conf/app/odoo.yml) config template.

```bash
curl -fsSL https://repo.pigsty.io/pig | bash
pig sty init              # init pigsty directory
pig sty boot              # prepare local repo & ansible
pig sty conf -c app/odoo  # use the odoo 1-node config template
pig sty install           # begin installation
```

Then install docker and launch odoo app:

```
./docker.yml              # install & configure docker & docker-compose
./app.yml                 # install and launch odoo with docker-compose
```

That's it, YOU ARE ALL SET! Odoo is serving on port 8069 by default, you can access it via `http://<ip>:8069`.

You can add a static entry to your `/etc/hosts` file to access odoo via `http://odoo.pigsty` through the nginx 80/443 portal

The template deliberately disables the database manager and locks the service
to `ODOO_DBNAME` through Odoo's exact database whitelist, with the regex filter
disabled. Dots and other regex characters in a database name remain literal.
Odoo interprets commas as database-list separators, so this single-database
template does not support names containing commas. A multi-database deployment
requires an explicit database-list design; grant only `CREATEDB` if needed,
never `SUPERUSER`.

The default `make` command initializes the database first and starts the web
service only after the initializer exits successfully. Both services use the
same filestore and addon directories. For manual deployment, run `make init`
before the first `make up`; do not start the web service against an empty database.
The directory targets read the resolved bind paths from Compose rather than
parsing `.env` as Make syntax, so quoted paths containing spaces are supported.
The Make helpers require `jq` on the Docker host.



--------

## Configuration

There's a config template [`conf/app/odoo`](https://github.com/pgsty/pigsty/blob/main/conf/app/odoo.yml), you'd better change some credentials and make your modifications there:

```yaml

all:
  children:

    # the odoo application (default username & password: admin/admin)
    odoo:
      hosts: { 10.10.10.10: {} }
      vars:
        app: odoo   # specify app name to be installed (in the apps)
        apps:       # define all applications
          odoo:     # app name, should have corresponding ~/app/odoo folder
            file:   # optional directory to be created
              - { path: /data/odoo         ,state: directory, owner: 100, group: 101 }
              - { path: /data/odoo/webdata ,state: directory, owner: 100, group: 101 }
              - { path: /data/odoo/addons  ,state: directory, owner: 100, group: 101 }
            conf:   # override /opt/<app>/.env config file
              PG_HOST: 10.10.10.10            # postgres host
              PG_PORT: 5432                   # postgres port
              PG_USERNAME: odoo               # postgres user
              PG_PASSWORD: DBUser.Odoo        # postgres password
              ODOO_PORT: 8069                 # odoo app port
              ODOO_DATA: /data/odoo/webdata   # odoo webdata
              ODOO_ADDONS: /data/odoo/addons  # odoo plugins
              ODOO_DBNAME: odoo               # odoo database name
              ODOO_ADMIN_PASSWORD: change-this-master-password
              ODOO_VERSION: 19.0              # follow Odoo 19

    # the odoo database
    pg-odoo:
      hosts: { 10.10.10.10: { pg_seq: 1, pg_role: primary } }
      vars:
        pg_cluster: pg-odoo
        pg_users:
          - { name: odoo    ,password: DBUser.Odoo ,pgbouncer: true ,roles: [ dbrole_admin ] ,comment: admin user for odoo service }
          - { name: odoo_ro ,password: DBUser.Odoo ,pgbouncer: true ,roles: [ dbrole_readonly ]  ,comment: read only user for odoo service  }
          - { name: odoo_rw ,password: DBUser.Odoo ,pgbouncer: true ,roles: [ dbrole_readwrite ] ,comment: read write user for odoo service }
        pg_databases:
          - { name: odoo ,owner: odoo ,revokeconn: true ,extensions: [unaccent, pg_trgm] ,comment: odoo main database }
        pg_hba_rules:
          - { user: odoo ,db: odoo ,addr: 172.16.0.0/12 ,auth: pwd ,title: 'allow odoo access from local docker networks' }
          - { user: dbuser_view , db: all ,addr: infra ,auth: pwd ,title: 'allow grafana dashboard access cmdb from infra nodes' }

```



-------

## Odoo Addons

There are lots of Odoo modules available in the community, you can install them by downloading and placing them in the `addons` folder (`/data/odoo/addons` by default).

```bash
mkdir -p /data/odoo/addons; chown 100:101 /data/odoo/addons
```

To enable addon module, first entering the [Developer mode](https://www.odoo.com/documentation/19.0/applications/general/developer_mode.html)

> Settings -> Generic Settings -> Developer Tools -> Activate the developer Mode

Then goes to the > Apps -> Update Apps List, then you can find the extra addons and install from the panel.

Frequently used [free](https://apps.odoo.com/apps/modules/browse?order=Downloads) addons: [Accounting Kit](https://apps.odoo.com/apps/modules/19.0/base_accounting_kit/)

## Upgrade Notes

Before pulling a new Odoo 19 image, back up both the PostgreSQL database and
`${ODOO_DATA}` filestore. Use a dated image tag when the deployment needs a
reproducible rollout or rollback point. A major-version upgrade requires an Odoo
database migration; changing only `ODOO_VERSION` is not sufficient.
