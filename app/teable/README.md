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
