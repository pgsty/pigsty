# Silo

Launch [Silo](https://silo.pgsty.com), Pigsty's S3-compatible object storage
fork, on ports 9000 and 9001. The APP follows `docker.io/pgsty/silo:latest`;
pin `SILO_IMAGE` explicitly only when a deployment needs a controlled upgrade
window or reproducible rollback.

Pigsty's native `MINIO` module already deploys Silo. Use this Docker Compose APP
only when an application-scoped standalone object store is more appropriate.
Do not reuse ports or a data directory owned by the native module. Set
`SILO_DATA`, `SILO_PORT`, and `SILO_CONSOLE_PORT` to separate values if both
deployments share a host.

When publishing the console on a port other than `9001`, or behind a reverse
proxy, set `SILO_BROWSER_REDIRECT_URL` to its complete external URL, for example
`http://silo.example.com:19001`. This controls browser redirects from the S3
endpoint; the container cannot infer the external hostname or published port.

```bash
cd ~/pigsty/app/silo
make up
```

The equivalent direct command is:

```bash
sudo mkdir -p /data/silo
docker run --name silo -p 9000:9000 -p 9001:9001 \
  -v /data/silo:/data \
  -e "MINIO_ROOT_USER=siloadmin" \
  -e "MINIO_ROOT_PASSWORD=S3User.Silo" \
  docker.io/pgsty/silo:latest server /data --console-address ":9001"
```

The S3 API is on port `9000`, and the console is on port `9001`. The default
credentials are `siloadmin` / `S3User.Silo`; change them before production use.
Object data persists in `/data/silo` on the host. Silo keeps the established
`MINIO_ROOT_*` container environment names for ecosystem compatibility; the
APP's public `.env` uses `SILO_*` names.

## Makefile

```bash
make up         # launch Silo with Docker Compose
make data       # create /data/silo for persistent object data
make run        # alias of make up
make view       # print Silo access points
make log        # follow Silo logs
make info       # inspect the Silo service
make health     # verify S3 readiness and the console HTTP endpoint
make stop       # stop the Silo container
make clean      # remove the container while preserving bind-mounted data
make pull       # pull the configured Silo image
make rmi        # remove the configured Silo image
make save       # save it to /tmp/docker/silo.tgz
make load       # load /tmp/docker/silo.tgz
```
