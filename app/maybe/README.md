# Maybe

[Maybe](https://github.com/maybe-finance/maybe) is an open-source personal finance application. This Pigsty app runs Maybe with Pigsty-managed PostgreSQL plus local Redis for Sidekiq jobs.

The upstream Maybe repository is archived. The latest upstream release is `v0.6.0`, while GHCR publishes `stable` and `latest` image tags. Pigsty defaults to `stable` for release-based self-hosting.

## Deploy

Use the Pigsty app template:

```bash
./configure -c app/maybe
vi pigsty.yml             # change passwords and SECRET_KEY_BASE
./deploy.yml              # install Pigsty and PostgreSQL on a fresh node
./docker.yml              # install Docker
./app.yml                 # install Maybe
```

For an existing Pigsty meta node, make sure the `maybe` user and `maybe_production` database from `conf/app/maybe.yml` are applied before starting the app.

## Access

Maybe listens on port `5002` by default:

```bash
http://maybe.pigsty
http://10.10.10.10:5002
```

## Configuration

The app uses `/opt/maybe/.env` after installation. Important variables:

```ini
MAYBE_VERSION=stable
MAYBE_IMAGE=ghcr.io/maybe-finance/maybe
MAYBE_PORT=5002
MAYBE_DATA=/data/maybe
APP_DOMAIN=maybe.pigsty
SECRET_KEY_BASE=...
DB_HOST=10.10.10.10
DB_PORT=5432
POSTGRES_USER=maybe
POSTGRES_PASSWORD=MaybeFinance2026
POSTGRES_DB=maybe_production
```

Generate a production secret with:

```bash
openssl rand -hex 64
```

## Management

Run these commands under `/opt/maybe` after `./app.yml` installs the app:

```bash
make up        # start Maybe
make down      # stop Maybe
make restart   # restart containers
make status    # show container status
make log       # follow logs
make health    # check Rails health endpoint
make migrate   # run Rails db:prepare manually
```

Persistent files live under `/data/maybe`; application data lives in the Pigsty PostgreSQL database.
