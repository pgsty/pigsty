# Configuration Template

This directory (`conf`) contains pigsty config templates, Which will be used during [`configure`](https://pigsty.io/docs/concept/iac/configure) procedure.

Config templates can be designated using `./configure -c <conf>`, where the conf is a relative path to `conf` directory (with or without `.yml` suffix).

```bash
./configure                     # use the meta.yml config template by default
./configure -c meta             # use the meta.yml 1-node template explicitly
./configure -c rich             # use the 1-node template with all extensions & minio
./configure -c slim             # use the minimal 1-node template

# use different kernels
./configure -c pgsql            # Vanilla PostgreSQL kernel with basic features (13~18)
./configure -c mssql            # Babelfish kernel with SQL Server wire-compatibility (15)
./configure -c polar            # PolarDB PG kernel for Aurora / RAC flavor postgres (15)
./configure -c ivory            # IvorySQL Kernel for Oracle grammar compatibility (18)
./configure -c mysql            # OpenHalo Kernel for MySQL Compatibility (14)
./configure -c pgtde            # Percona PostgreSQL Server with TDE (18)
./configure -c oriole           # OrioleDB Kernel for OLTP Enhancement (17)
./configure -c supabase         # PostgreSQL configured for Supabase self-hosting (15~18)

# use multi-node HA templates
./configure -c ha/dual          # use the 2-node HA template
./configure -c ha/trio          # use the 3-node HA template
./configure -c ha/full          # use the 4-node HA template
./configure -c ha/citus         # use the 13-node HA citus template
./configure -c ha/simu          # use the 20-node HA prod template

# special configuration
./configure -c vibe             # 1-node vibe coding devbox
```

Pigsty will use the `meta.yml` single node config template if you do not specify a conf.


----------

## Main Templates

These are 1-node config template, which can be used to install pigsty on a single node:

* [meta.yml](meta.yml) : **DEFAULT**,  1-node PostgreSQL online installation
* [rich.yml](rich.yml) : feature-rich config with local repo, minio, and more examples
* [slim.yml](slim.yml) : install postgres directly without monitoring and infra
* [fat.yml](fat.yml) : extreme feature-rich config with all extensions installed!
* [infra.yml](infra.yml) : only install the infra components without postgres
* [vibe.yml](vibe.yml) : 1-node vibe coding devbox with pgsql and various tools

**Templates for exotic DBMS and kernels:**

* [pgsql.yml](pgsql.yml) : Vanilla PostgreSQL kernel with basic features (13~18)
* [mssql.yml](mssql.yml) : Babelfish kernel with SQL Server wire-compatibility (15)
* [polar.yml](polar.yml) : PolarDB PG kernel for Aurora / RAC flavor postgres (15)
* [ivory.yml](ivory.yml) : IvorySQL Kernel for Oracle grammar compatibility (18)
* [mysql.yml](mysql.yml) : OpenHalo Kernel for MySQL Compatibility (14)
* [pgtde.yml](pgtde.yml) : Percona PostgreSQL Server with TDE (18)
* [oriole.yml](oriole.yml) : OrioleDB Kernel for OLTP Enhancement (17, deb broken)
* [supabase.yml](supabase.yml) : PostgreSQL configured for Supabase self-hosting (15~18)

You can add more nodes later, or use [HA config templates](#ha-templates) to plan it at the beginning.


--------

## HA Templates

You can configure pigsty to run on multiple nodes to form a high availability (HA) cluster.

* [ha/dual.yml](ha/dual.yml) : 2-node semi-ha deployment
* [ha/trio.yml](ha/trio.yml) : 3-node standard ha deployment
* [ha/full.yml](ha/full.yml) : 4-node standard deployment
* [ha/safe.yml](ha/safe.yml) : 4-node security enhanced setup with delayed replica
* [ha/citus.yml](ha/citus.yml) : 13-node distributive citus cluster
* [ha/simu.yml](ha/simu.yml) : 20-node Production simulation


----------

## App Templates

You can run docker software/app with the following templates:

* [app/supa.yml](app/supa.yml) : launch 1-node supabase
* [app/odoo.yml](app/odoo.yml) : launch the odoo ERP system
* [app/dify.yml](app/dify.yml) : launch the dify AI workflow system
* [app/electric.yml](app/electric.yml) : launch the electric sync engine app

----------

## Demo Templates

In addition to the main templates, Pigsty provides a set of demo templates for different scenarios.

* [demo/el.yml](demo/remote.yml) : config file with all default parameters for EL 8/9 systems.
* [demo/debian.yml](demo/debian.yml) : config file with all default parameters for debian/ubuntu systems.
* [demo/remote.yml](demo/remote.yml) : example config for monitoring a remote pgsql cluster or RDS PG.
* [demo/redis.yml](demo/redis.yml) : example config for redis clusters
* [demo/minio.yml](demo/minio.yml) : example config for a 3-node minio clusters
* [demo/demo.yml](demo/demo.yml) : config file for the pigsty [public demo](https://demo.pigsty.io)

----------

## Building Templates

These config templates are used for development and testing purposes.

* [build/oss.yml](build/oss.yml) : building config for EL 9, 10 ,Debian 12/13, and Ubuntu 22.04/24.04 OSS.
