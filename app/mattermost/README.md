# Mattermost

This template runs Mattermost Team Edition with an external Pigsty PostgreSQL
database. Review `.env` before launch, especially `POSTGRES_URL`, `DOMAIN`, and
the image tag.

```bash
cd ~/pigsty/app/mattermost
sudo make up      # create bind mounts owned by uid/gid 2000 and start Compose
make view
```

The default HTTP port is `8065`. Persistent files live under `./volumes`; the
Mattermost database must be backed up separately. `make clean` removes the
container but preserves both the bind-mounted files and PostgreSQL data.

```bash
make up       # create directories and start Mattermost
make view     # print the access endpoint
make log      # follow container logs
make info     # inspect the container
make restart  # restart the Compose service
make stop     # stop the container
make clean    # remove the container, preserving data
make pull     # pull the configured image
make save     # save the image to /tmp/docker/mattermost.tgz
make load     # load the saved image
```
