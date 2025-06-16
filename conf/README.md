# Configuration Template

This directory (`conf`) contains pigsty config templates, Which will be used during [`configure`](https://pgsty.com/docs/config/configure) procedure.

Config templates can be designated using `./configure -c <conf>`, where the conf is a relative path to `conf` directory (with or without `.yml` suffix).

```bash
./configure                     # use the meta.yml config template by default
./configure -c meta             # use the meta.yml 1-node template explicitly
./configure -c rich             # use the 1-node template with all extensions & minio
./configure -c slim             # use the minimal 1-node template
./configure -c app/supa         # use the supabase 1-node template
./configure -c demo/citus       # use the 4-node citus template
```

Pigsty will use the `meta.yml` single node config template if you do not specify a conf. 


----------

## Main Templates

**1-node config template for standard, featured-rich, and slim mode**:

* [meta.yml](meta.yml) : default config for a singleton node deployment
* [rich.yml](rich.yml) : 1-node rich config, run multiple database and install all extensions.
* [slim.yml](slim.yml) : 1-node slim config, deploy PostgreSQL without infra and local repo & infra

**Templates for exotic DBMS and kernels:**

* [mssql.yml](mssql.yml) : example config for WiltonDB & Babelfish Cluster with MSSQL compatibility
* [polar.yml](polar.yml) : PolarDB for PostgreSQL config example: PG with RAC
* [ivory.yml](ivory.yml) : IvorySQL cluster config example: Oracle Compatibility
* [mysql.yml](mysql.yml) : openHalo cluster config example: MySQL Compatibility
* [oriole.yml](oriole.yml) : OrioleDB cluster example: OLTP Enhancement
* [pg18.yml](pg18.yml) : PostgreSQL 18 cluster config example, still in beta

Boilerplate for adding more nodes

* [dual.yml](dual.yml) : 2-node semi-ha deployment
* [trio.yml](trio.yml) : 3-node standard ha deployment
* [full.yml](full.yml) : 4-node standard deployment
* [safe.yml](safe.yml) : 4-node security enhanced setup with delayed replica
* [simu.yml](simu.yml) : 36-node Production simulation


----------

## App Templates

You can run docker software/app with the following templates:

* [app/supa.yml](app/supa.yml) : launch 1-node supabase
* [app/odoo.yml](app/odoo.yml) : launch the odoo ERP system
* [app/dify.yml](app/dify.yml) : launch the dify AI workflow system
* [app/electirc.yml](app/electric.yml) : launch the electric sync engine app

----------

## Demo Templates

In addition to the main templates, Pigsty provides a set of demo templates for different scenarios.

* [demo/el.yml](demo/remote.yml) : config file with all default parameters for EL 8/9 systems.
* [demo/debian.yml](demo/debian.yml) : config file with all default parameters for debian/ubuntu systems.
* [demo/remote.yml](demo/remote.yml) : example config for monitoring a remote pgsql cluster or RDS PG.
* [demo/redis.yml](demo/redis.yml) : example config for redis clusters
* [demo/minio.yml](demo/minio.yml) : example config for a 3-node minio clusters
* [demo/demo.yml](demo/demo.yml) : config file for the pigsty [public demo](https://demo.pigsty.cc)
* [demo/citus.yml](demo/citus.yml) : citus cluster example: 1 coordinator and 3 data nodes (4-node)

----------

## Building Templates

There config templates are used for development and testing purpose.

* [build/oss.yml](build/oss.yml) : building config for EL 8, 9, Debian 12, and Ubuntu 22.04/24.04 OSS.
* [build/pro.yml](build/pro.yml) : building config for EL 7-9, Ubuntu, Debian pro version
