# teable

teable: https://teable.io/

AI No-code Database, Productivity Super Boost

The database designed for every team: generating, automating, collaborating with AI

```bash
curl -fsSL https://repo.pigsty.io/get | bash; cd ~/pigsty
cd ~/pigsty
./bootstrap               # prepare local repo & ansible
./configure -c app/teable # IMPORTANT: CHANGE CREDENTIALS!!
./deploy.yml              # install pigsty & pgsql & minio
./redis.yml               # install extra redis instances
./docker.yml              # install docker & docker-compose
./app.yml                 # install teable with docker compose
```

The web service listens on port `8890` by default. Configuration is read from
`.env`; `TEABLE_DATA` controls the persistent asset directory (default:
`/data/teable`). PostgreSQL remains the source of truth for application data,
so back up both the `teable` database and the asset directory.

`make view` prints only the endpoint and persistent path; it intentionally does
not print `.env`, because that file contains database credentials.
