# FerretDB

[FerretDB](https://www.ferretdb.com/) provides a MongoDB-compatible wire protocol on top of PostgreSQL and the DocumentDB extension.

This app only runs the stateless FerretDB proxy. PostgreSQL, the `postgres` database, the DocumentDB extension, and the backend login must exist first. The [`conf/mongo.yml`](../../conf/mongo.yml) template supplies all of them.

## Deploy with the Mongo template

```bash
./configure -c mongo
./deploy.yml
./docker.yml -l pg-meta
./app.yml -l pg-meta
```

Connect with the dedicated PostgreSQL/FerretDB login declared by the template:

Install `mongosh` separately if it is not already available, or use another MongoDB-compatible client.

```bash
mongosh 'mongodb://mongod:DBUser.Mongo@127.0.0.1:27017/'
```

Authentication is enabled. FerretDB currently authenticates users through PostgreSQL but does not implement MongoDB authorization, so MongoDB roles do not provide access isolation.

## Configuration

The defaults are in [`.env`](.env). Override them through `apps.ferretdb.conf` in the Pigsty inventory instead of editing the deployed `/opt/ferretdb/.env` file:

```yaml
app: ferretdb
apps:
  ferretdb:
    conf:
      FERRETDB_IMAGE: ghcr.io/ferretdb/ferretdb:2.7.0
      FERRETDB_POSTGRESQL_URL: 'postgres://mongod:DBUser.Mongo@host.docker.internal:5436/postgres?pool_min_conns=1&pool_max_conns=20'
      FERRETDB_BIND_ADDR: 127.0.0.1
      FERRETDB_PORT: 27017
      FERRETDB_AUTH: true
      FERRETDB_TELEMETRY: disabled
```

Port `5436` is Pigsty's direct-to-primary PostgreSQL service. The Linux `host-gateway` mapping keeps the backend address local to the container host while preserving Pigsty's primary routing. The MongoDB port defaults to loopback only; set `FERRETDB_BIND_ADDR` explicitly when remote clients need access.

The image's built-in health check is retained. Its debug endpoint is not published, and this app does not add a dedicated dashboard, log pipeline, or VictoriaMetrics target.

FerretDB releases name a preferred DocumentDB version. Pigsty may ship a newer compatible DocumentDB package, so repeat an authenticated CRUD smoke test after either component is upgraded.

The template does not enable client-side MongoDB TLS. Add TLS certificates and the `FERRETDB_LISTEN_TLS*` variables before exposing this service on an untrusted network.

## Optional three-node HA topology

[`conf/mongo.yml`](../../conf/mongo.yml) includes a commented three-node PostgreSQL/DocumentDB cluster with one FerretDB container per node. Uncomment the complete `pg-mongo` block and the two additional etcd members to enable it. Each container publishes host port `27018`; HAProxy on the three application nodes exposes the standard MongoDB port through the floating endpoint `10.10.10.4:27017` (`mongo.pigsty`).

```bash
./configure -c mongo
./deploy.yml
./docker.yml -l pg-mongo
./app.yml -l pg-mongo
mongosh 'mongodb://mongod:DBUser.Mongo@10.10.10.4:27017/'
```

The HAProxy health check is TCP-level. It removes a stopped or unreachable FerretDB process from rotation, while FerretDB's own image health check continues to validate the backend connection inside each container.

The demo intentionally retains Pigsty's local pgBackRest default. A production HA deployment should use a shared MinIO/S3 repository so a newly promoted PostgreSQL primary has access to the same backup history.
