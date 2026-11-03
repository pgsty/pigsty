# teable

teable: https://teable.io/

AI No-code Database, Productivity Super Boost

The database designed for every team: generating, automating, collaborating with AI

```bash
curl -fsSL https://repo.pigsty.io/get | bash; cd ~/pigsty
cd ~/pigsty
./bootstrap               # prepare local repo & ansible
./configure -c app/teable # IMPORTANT: CHANGE CREDENTIALS!!
./deploy.yml              # install Pigsty, PostgreSQL, and Silo
./docker.yml              # install docker & docker-compose
./app.yml                 # install teable with docker compose
```

The web service listens on port `8890` by default. Configuration is read from
`.env`; `TEABLE_DATA` controls the persistent asset directory (default:
`/data/teable`). PostgreSQL remains the source of truth for application data,
so back up both the `teable` database and the asset directory.

The current release also requires Redis. Compose starts a private, authenticated
Redis 7.4 instance and preserves its AOF in a named volume; no separate
`redis.yml` deployment or published Redis port is needed. Set a new
`REDIS_PASSWORD` before production. Compose derives `BACKEND_CACHE_REDIS_URI`
from the final `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`, and `REDIS_DB` values.
The Redis server, application, and health check all follow `REDIS_PORT`, including
shell and `--env-file` overrides. Leave `BACKEND_CACHE_REDIS_URI` unset unless
intentionally supplying a complete URI; remove the older derived `.env` line
when upgrading so layered env files cannot freeze its previous port/password.
The application waits for Redis and its health check verifies the backend's
database-aware `/health` endpoint, not only the frontend page.

`make view` prints only the endpoint and persistent path; it intentionally does
not print `.env`, because that file contains database credentials.
