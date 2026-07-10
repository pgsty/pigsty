# minio

Launch minio (s3) service on 9000 & 9001, you can also use the built-in minio support.

```bash
cd ~/pigsty/app/minio
make up
```

```bash
sudo mkdir -p /data/minio
docker run -p 9000:9000 -p 9001:9001 \
  -v /data/minio:/data \
  -e "MINIO_ROOT_USER=minioadmin" \
  -e "MINIO_ROOT_PASSWORD=S3User.MinIO" \
  pgsty/minio server /data --console-address ":9001"
```

The S3 API is on port `9000`, and the console is on port `9001`. The default
credentials are `minioadmin` / `S3User.MinIO`. Change them before production use.
Object data persists in `/data/minio` on the host.

## Makefile

```bash
make up         # pull up minio with docker compose
make data       # create /data/minio for persistent object data
make run        # launch minio with docker
make view       # print minio access point
make log        # tail -f minio logs
make info       # introspect minio with jq
make stop       # stop minio container
make clean      # remove minio container
make pull       # pull latest minio image
make rmi        # remove minio image
make save       # save minio image to /tmp/docker/minio.tgz
make load       # load minio image from /tmp/docker/minio.tgz
```
