# Immich

[Immich](https://github.com/immich-app/immich) is a high performance
self-hosted photo and video management application. This Pigsty template runs
Immich with Docker Compose while using a Pigsty-managed PostgreSQL database.

The template follows Immich v3 and uses VectorChord for smart search and face
search vectors.

## Architecture

This stack runs:

- `immich-server`: API, web UI, and background jobs on port `2283`.
- `immich-machine-learning`: CLIP and face-recognition model inference.
- `redis`: local Valkey queue/cache for background jobs.

This stack does not run Immich's upstream PostgreSQL container. PostgreSQL is
provided by Pigsty through `DB_URL`.

## Usage

Use the Pigsty config template:

```bash
curl -fsSL https://repo.pigsty.io/get | bash
cd ~/pigsty
./bootstrap
./configure -c app/immich
vi pigsty.yml              # change passwords, domain, and storage paths
./deploy.yml               # install Pigsty and PostgreSQL
./docker.yml               # install Docker and Compose
./app.yml                  # install Immich
```

The default URL is:

```text
http://photo.pigsty
http://10.10.10.10:2283
```

## PostgreSQL

Immich connects to Pigsty PostgreSQL with:

```text
DB_URL=postgresql://dbuser_immich:DBUser.Immich@10.10.10.10:5432/immich
DB_VECTOR_EXTENSION=vectorchord
```

The direct `5432` connection is intentional. Avoid pointing Immich at a Pigsty
service backed by PgBouncer transaction pooling, because Immich migrations and
prepared statements are safer with direct PostgreSQL or session pooling.

The Pigsty template installs the required extension packages and creates these
database extensions before Immich starts:

```sql
CREATE EXTENSION vchord CASCADE;
CREATE EXTENSION earthdistance CASCADE;
```

`vchord` requires `vchord.so` in `shared_preload_libraries`, which is configured
through `pg_libs`.

## VectorChord Upgrades

After upgrading VectorChord packages, connect to the `immich` database and run:

```sql
ALTER EXTENSION vchord UPDATE;
REINDEX INDEX face_index;
REINDEX INDEX clip_index;
```

Reindexing can take a long time on large libraries. Do not interrupt it unless
you have verified that it is stuck.

## Media Storage

Immich stores uploaded media and generated assets in the host path configured by
`UPLOAD_LOCATION`, which defaults to:

```text
/data/immich/library
```

PostgreSQL stores metadata and file paths. The media files are not stored in
PostgreSQL and are not protected by pgBackRest.

Back up both layers:

- PostgreSQL: Pigsty pgBackRest.
- Media files: file-level backup of `/data/immich/library`.

For the most consistent combined backup, stop `immich-server` before backing up
both layers. If the service cannot be stopped, back up the database first and
the filesystem second.

## Images and China Networks

Images are pulled from GHCR and Docker Hub:

```bash
docker pull ghcr.io/immich-app/immich-server:v3
docker pull ghcr.io/immich-app/immich-machine-learning:v3
docker pull docker.io/valkey/valkey:9
```

If image pulls are slow or blocked, configure Pigsty's `proxy_env` or
`docker_registry_mirrors` in `pigsty.yml`.

## Operations

Run these commands under `/opt/immich` after `./app.yml` installs the app:

```bash
make up       # start Immich
make logs     # follow logs
make info     # show container status
make pull     # pull images
make restart  # restart containers
make down     # stop and remove containers
```

To pin a specific Immich release, set `IMMICH_VERSION` in `pigsty.yml`, for
example:

```yaml
IMMICH_VERSION: v3.0.1
```

Before major upgrades, check the official Immich release notes for PostgreSQL,
pgvector, and VectorChord compatibility changes.
