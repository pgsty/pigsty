# PGWEB

PGWEB: https://github.com/sosedoff/pgweb

Simple web-based and cross platform PostgreSQL database explorer.

The template follows the untagged `sosedoff/pgweb` image; the 2026-08-27
validation snapshot resolved to `0.17.0`. Override `PGWEB_PORT` in `.env` when
needed. Keep this database administration endpoint on a trusted network or
behind an authenticated proxy.


```bash
cd ~/pigsty/app/pgweb ; make up
```

Visit [http://cli.pigsty](http://cli.pigsty) or http://10.10.10.10:8886 

Try connecting with example URLs:

```bash
postgres://dbuser_meta:DBUser.Meta@10.10.10.10:5432/meta?sslmode=disable
postgres://test:test@10.10.10.11:5432/test?sslmode=disable
```

```bash
make up         # pull up pgweb with docker compose
make run        # launch pgweb with docker
make view       # print pgweb access point
make log        # tail -f pgweb logs
make info       # introspect pgweb with jq
make stop       # stop pgweb container
make clean      # remove pgweb container
make pull       # pull latest pgweb image
make rmi        # remove pgweb image
make save       # save pgweb image to /tmp/docker/pgweb.tgz
make load       # load pgweb image from /tmp/docker/pgweb.tgz
```
