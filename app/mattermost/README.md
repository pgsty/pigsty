# Mattermost

This template runs Mattermost Team Edition with an external Pigsty PostgreSQL
database. Review `.env` before launch, especially `POSTGRES_URL`, `DOMAIN`, and
the image tag. The default follows Mattermost's `latest` Team Edition image; the
2026-08-27 validation snapshot resolved to `11.10.1`. Pin a release explicitly
when an installation needs a controlled database-upgrade and rollback window.
See the [official release notes](https://docs.mattermost.com/product-overview/mattermost-v11-changelog.html).

The official Team Edition image is currently `linux/amd64` only. Use an x86-64
host for production. ARM64 development hosts require separately configured
QEMU/binfmt emulation and a test-only Compose override with `platform: linux/amd64`;
emulated tests do not establish native ARM64 support.

For ARM64 smoke tests, use a current emulator. Ubuntu 24.04's packaged QEMU
8.2 crashed while starting Mattermost 11.10.1; the same official image ran with
QEMU 10.2.3 from Docker's documented `tonistiigi/binfmt` setup. A VM reboot may
restore the distribution's older binfmt registration.

The current image is distroless (no shell or `curl`). Its built-in health check
uses `mmctl system status --local`; `make health` runs the same check.

```bash
cd ~/pigsty/app/mattermost
sudo make up      # prepare the resolved bind mounts as uid/gid 2000, then start Compose
make view
```

The default HTTP port is `8065`; Calls uses TCP and UDP port `8443`. Persistent
files live under `./volumes` when running this directory directly. Deployments
from `conf/app/mattermost.yml` use `/data/mattermost/*` instead. The Mattermost
database must be backed up separately. `make clean` removes the container but
preserves both the bind-mounted files and PostgreSQL data.

`make mkdir` uses Python 3 to read `docker compose config`, so custom
`MATTERMOST_*_PATH` bind mounts receive the same ownership as the defaults.
It refuses broad paths such as `/data` or the application directory itself;
use dedicated subdirectories for Mattermost data.

Pigsty's default zone firewall trusts intranet clients but does not expose
Calls media publicly. For Internet users, explicitly allow both TCP and UDP
`8443` (the generic `node_firewall_public_port` helper opens TCP only), or
configure Mattermost Calls with an appropriate TURN deployment.

```bash
make up       # create directories and start Mattermost
make view     # print the access endpoint
make log      # follow container logs
make info     # inspect the container
make health   # verify server status through the local mmctl socket
make restart  # restart the Compose service
make stop     # stop the container
make clean    # remove the container, preserving data
make pull     # pull the configured image
make save     # save the image to /tmp/docker/mattermost.tgz
make load     # load the saved image
```

Before pulling a newer image, back up PostgreSQL plus the config, data, plugins,
and Bleve directories and record the currently resolved version. Never apply an
older image tag to a database already migrated by a newer version. Use an exact
tag instead of `latest` wherever the deployment process requires an explicit
review or rollback point.
