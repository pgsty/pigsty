#==============================================================#
# File      :   Dockerfile
# Desc      :   Pigsty Docker Images based on Debian 13 (Trixie)
# Ctime     :   2025-01-27
# Mtime     :   2025-01-27
# License   :   Apache-2.0 @ https://pigsty.io/docs/about/license
# Copyright :   2018-2025  Ruohang Feng / Vonng (rh@vonng.com)
#==============================================================#
#
# Multi-stage build producing 5 images:
#
#   linux   - Base Debian 13 with systemd and SSH
#   admin   - linux + pig CLI + Ansible + node packages (default)
#   infra   - admin + infra packages (monitoring infrastructure)
#   pgsql   - infra + PostgreSQL 18 core packages
#   pigsty  - pgsql + all PostgreSQL extensions (full version)
#
# Build:
#   docker build --target pigsty -t pgsty/pigsty:v4.0.0 .
#
# Run (works on both macOS and Linux):
#   docker run -d --privileged --name pigsty \
#     -p 2222:22 -p 8080:80 -p 5432:5432 pgsty/pigsty:v4.0.0
#
#==============================================================#


#--------------------------------------------------------------#
# Stage 1: linux
#--------------------------------------------------------------#
# Base Debian 13 (Trixie) with systemd enabled
#   - systemd configured for container environment
#   - SSH server configured (root:pigsty)
#   - Essential tools: curl, wget, vim, git, jq, etc.
#--------------------------------------------------------------#
FROM debian:trixie AS linux

LABEL maintainer="Ruohang Feng <rh@vonng.com>"
LABEL org.opencontainers.image.title="Pigsty Linux"
LABEL org.opencontainers.image.description="Pigsty Debian 13 Linux Node"
LABEL org.opencontainers.image.url="https://pigsty.io"
LABEL org.opencontainers.image.source="https://github.com/pgsty/pigsty"
LABEL org.opencontainers.image.version="4.0.0"

ENV container=docker \
    DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PIGSTY_VERSION=v4.0.0

# Install systemd and essential packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    systemd systemd-sysv dbus dbus-user-session \
    openssh-server openssh-client sudo \
    locales ca-certificates curl wget \
    vim git jq lz4 make bash lsof rsync ncdu \
    python3 procps iproute2 net-tools iputils-ping \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Configure systemd for container environment
# Remove unnecessary services that don't work in containers
RUN cd /lib/systemd/system/sysinit.target.wants/ \
    && rm -f $(ls | grep -v systemd-tmpfiles-setup) \
    && rm -f /lib/systemd/system/multi-user.target.wants/* \
    && rm -f /etc/systemd/system/*.wants/* \
    && rm -f /lib/systemd/system/local-fs.target.wants/* \
    && rm -f /lib/systemd/system/sockets.target.wants/*udev* \
    && rm -f /lib/systemd/system/sockets.target.wants/*initctl* \
    && rm -f /lib/systemd/system/basic.target.wants/* \
    && rm -f /lib/systemd/system/anaconda.target.wants/* \
    && rm -f /lib/systemd/system/plymouth* \
    && rm -f /lib/systemd/system/systemd-update-utmp* \
    && systemctl set-default multi-user.target

# Mask services that cause issues in containers
RUN systemctl mask \
    dev-hugepages.mount \
    sys-fs-fuse-connections.mount \
    systemd-update-utmp.service \
    systemd-tmpfiles-setup.service \
    console-getty.service

# Configure locale and timezone
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen en_US.UTF-8 \
    && ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo "${TZ}" > /etc/timezone

# Configure SSH
RUN mkdir -p /run/sshd /root/.ssh \
    && chmod 700 /root/.ssh \
    && ssh-keygen -A \
    && sed -i 's/#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && systemctl enable ssh

# Configure sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/nopasswd \
    && chmod 440 /etc/sudoers.d/nopasswd

# Set root password
RUN echo 'root:pigsty' | chpasswd

# Create postgres user/group with fixed UID/GID=543 (before any PG packages)
RUN groupadd -g 543 postgres && useradd -u 543 -g 543 -m -s /bin/bash postgres

# Finalize linux stage
RUN mkdir -p /data
WORKDIR /root
VOLUME ["/data"]
EXPOSE 22 80 443 5432
STOPSIGNAL SIGRTMIN+3
CMD ["/lib/systemd/systemd"]


#--------------------------------------------------------------#
# Stage 2: admin (default)
#--------------------------------------------------------------#
# Admin node with pig CLI, Ansible, and node packages
#   - pig CLI from Pigsty APT repository
#   - Pigsty source initialized via `pig sty init`
#   - Ansible installed via `pig sty boot`
#   - Upstream repos configured via `pig repo add -r`
#   - Node packages for managed nodes
#--------------------------------------------------------------#
FROM linux AS admin

LABEL org.opencontainers.image.title="Pigsty Admin"
LABEL org.opencontainers.image.description="Pigsty Admin Node with Ansible"

# Install pig CLI
RUN echo "deb [trusted=yes] https://repo.pigsty.cc/apt/infra/ generic main" \
    > /etc/apt/sources.list.d/pigsty.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends pig \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Initialize Pigsty and install Ansible
RUN pig sty init -v ${PIGSTY_VERSION} \
    && pig sty boot \
    && pig sty conf -c docker --ip 127.0.0.1

# Add upstream repos (without caching packages)
RUN pig repo add -r \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Prevent services from auto-starting during installation
RUN echo '#!/bin/sh\nexit 101' > /usr/sbin/policy-rc.d && chmod +x /usr/sbin/policy-rc.d

# Install node packages (from node_packages_default in d13.x86_64.yml)
RUN apt-get update && apt-get install -y --no-install-recommends \
    lz4 unzip bzip2 pv jq git ncdu make patch bash lsof wget tuned nvme-cli numactl sysstat iotop htop rsync tcpdump \
    python3 socat net-tools ipvsadm telnet ca-certificates openssl keepalived etcd haproxy chrony cron pig uv \
    zlib1g acl bind9-dnsutils libreadline-dev vim-tiny node-exporter openssh-server openssh-client vector \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Enable profile.d scripts in interactive bash sessions
RUN printf '\n# Load /etc/profile.d scripts\nif [ -d /etc/profile.d ]; then\n  for i in /etc/profile.d/*.sh; do\n    if [ -r "$i" ]; then\n      . "$i"\n    fi\n  done\nfi\n' >> /root/.bashrc

WORKDIR /root/pigsty


#--------------------------------------------------------------#
# Stage 3: infra
#--------------------------------------------------------------#
# Infrastructure node with monitoring components
# Packages from infra_packages_default in d13.x86_64.yml
#--------------------------------------------------------------#
FROM admin AS infra

LABEL org.opencontainers.image.title="Pigsty Infra"
LABEL org.opencontainers.image.description="Pigsty Infrastructure Node"

RUN apt-get update && apt-get install -y --no-install-recommends \
    grafana grafana-plugins grafana-victorialogs-ds grafana-victoriametrics-ds victoria-metrics victoria-logs victoria-traces vmutils vlogscli alertmanager \
    node-exporter blackbox-exporter nginx-exporter pg-exporter pev2 nginx dnsmasq ansible etcd python3-requests redis mcli restic certbot python3-certbot-nginx \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Disable auto-start services (will be managed by Pigsty)
RUN systemctl disable alertmanager blackbox_exporter nginx nginx_exporter node_exporter 2>/dev/null || true


#--------------------------------------------------------------#
# Stage 4: pgsql
#--------------------------------------------------------------#
# PostgreSQL node with core packages and HA tools
# Packages: pg18-main + pgsql-common from d13.x86_64.yml
#--------------------------------------------------------------#
FROM infra AS pgsql

LABEL org.opencontainers.image.title="Pigsty PGSQL"
LABEL org.opencontainers.image.description="Pigsty PostgreSQL Node"

RUN apt-get update \
    && pig install -y postgresql-18 postgresql-client-18 postgresql-plpython3-18 postgresql-plperl-18 postgresql-pltcl-18 postgresql-18-repack postgresql-18-wal2json postgresql-18-pgvector patroni python3-etcd pgbouncer pgbackrest pg-exporter pgbackrest-exporter vip-manager \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Remove PostgreSQL systemd service (will be managed by Patroni)
# postgresql.service: main service, postgresql@.service: template for postgresql@<ver>-<cluster>
RUN rm -f /lib/systemd/system/postgresql.service /lib/systemd/system/postgresql@.service \
    && rm -rf /etc/systemd/system/postgresql.service /etc/systemd/system/postgresql@.service \
              /etc/systemd/system/postgresql.service.d /etc/systemd/system/postgresql@.service.d \
              /etc/systemd/system/*.wants/postgresql* 2>/dev/null || true


#--------------------------------------------------------------#
# Stage 5: pigsty
#--------------------------------------------------------------#
# Full Pigsty node with all PostgreSQL 18 extensions
# Packages from pg18-* in d13.x86_64.yml
#--------------------------------------------------------------#
FROM pgsql AS pigsty

LABEL org.opencontainers.image.title="Pigsty"
LABEL org.opencontainers.image.description="Battery-Included PostgreSQL Distribution"

# Install all PostgreSQL 18 extensions by category
RUN apt-get update
RUN apt-get install -y postgresql-18-timescaledb-tsl postgresql-18-timescaledb-toolkit postgresql-18-pg-timeseries postgresql-18-periods postgresql-18-temporal-tables postgresql-18-emaj postgresql-18-table-version postgresql-18-cron postgresql-18-pg-task postgresql-18-pg-later postgresql-18-pg-background
RUN apt-get install -y postgresql-18-postgis-3 postgresql-18-pgrouting postgresql-18-pointcloud postgresql-18-h3 postgresql-18-q3c postgresql-18-ogr-fdw postgresql-18-geoip postgresql-18-pg-polyline postgresql-18-pg-geohash postgresql-18-mobilitydb postgresql-18-tzf
RUN apt-get install -y postgresql-18-pgvector postgresql-18-vchord postgresql-18-pgvectorscale postgresql-18-pg-vectorize postgresql-18-similarity postgresql-18-smlar postgresql-18-pg-summarize postgresql-18-pg-tiktoken postgresql-18-pg4ml
RUN apt-get install -y postgresql-18-pg-search postgresql-18-pgroonga postgresql-18-pg-bigm postgresql-18-zhparser postgresql-18-pg-bestmatch postgresql-18-vchord-bm25 postgresql-18-pg-tokenizer postgresql-18-biscuit postgresql-18-textsearch postgresql-18-hunspell-cs-cz postgresql-18-hunspell-de-de postgresql-18-hunspell-en-us postgresql-18-hunspell-fr postgresql-18-hunspell-ne-np postgresql-18-hunspell-nl-nl postgresql-18-hunspell-nn-no postgresql-18-hunspell-ru-ru postgresql-18-hunspell-ru-ru-aot
RUN apt-get install -y postgresql-18-citus postgresql-18-pg-duckdb postgresql-18-pg-mooncake postgresql-18-clickhouse postgresql-18-pg-parquet postgresql-18-pg-fkpart postgresql-18-partman postgresql-18-plproxy
RUN apt-get install -y postgresql-18-age postgresql-18-hll postgresql-18-rum postgresql-18-ai-query postgresql-18-ttl-index postgresql-18-pg-graphql postgresql-18-pg-jsonschema postgresql-18-jsquery postgresql-18-pg-hint-plan postgresql-18-hypopg postgresql-18-index-advisor postgresql-18-pg-plan-filter postgresql-18-pg-ivm postgresql-18-pg-incremental postgresql-18-pgmq postgresql-18-pgq3 postgresql-18-pg-cardano postgresql-18-rdkit postgresql-18-omnigres
RUN apt-get install -y postgresql-18-pg-tle postgresql-18-plv8 postgresql-18-pljs postgresql-18-pllua postgresql-18-plprql postgresql-18-pldebugger postgresql-18-plpgsql-check postgresql-18-plprofiler postgresql-18-plsh postgresql-18-plxslt postgresql-18-pgtap
RUN apt-get install -y postgresql-18-prefix postgresql-18-semver postgresql-18-unit postgresql-18-pgpdf postgresql-18-pglite-fusion postgresql-18-md5hash postgresql-18-asn1oid postgresql-18-roaringbitmap postgresql-18-pgfaceting postgresql-18-pgsphere postgresql-18-pg-country postgresql-18-pg-xenophile postgresql-18-pg-currency postgresql-18-collection postgresql-18-pgmp postgresql-18-numeral postgresql-18-rational postgresql-18-pguint postgresql-18-pg-uint128 postgresql-18-hashtypes postgresql-18-ip4r postgresql-18-pg-duration postgresql-18-pg-uri postgresql-18-pg-emailaddr postgresql-18-acl postgresql-18-debversion postgresql-18-pg-rrule postgresql-18-timestamp9 postgresql-18-chkpass
RUN apt-get install -y postgresql-18-gzip postgresql-18-bzip postgresql-18-zstd postgresql-18-http postgresql-18-pg-net postgresql-18-pg-curl postgresql-18-retry postgresql-18-pgjq postgresql-18-pgjwt postgresql-18-pg-smtp-client postgresql-18-pg-html5-email-address postgresql-18-url-encode postgresql-18-pgsql-tweaks postgresql-18-pg-extra-time postgresql-18-pgpcre postgresql-18-icu-ext postgresql-18-pgqr postgresql-18-pg-protobuf postgresql-18-pg-envvar postgresql-18-floatfile postgresql-18-pg-render postgresql-18-pg-readme postgresql-18-ddl-historization postgresql-18-data-historization postgresql-18-pg-schedoc postgresql-18-pg-hashlib postgresql-18-pg-xxhash postgresql-18-shacrypt postgresql-18-cryptint postgresql-18-pg-ecdsa postgresql-18-pgsparql
RUN apt-get install -y postgresql-18-pg-idkit postgresql-18-pgx-ulid postgresql-18-pg-uuidv7 postgresql-18-permuteseq postgresql-18-pg-hashids postgresql-18-sequential-uuids postgresql-18-typeid postgresql-18-topn postgresql-18-quantile postgresql-18-lower-quantile postgresql-18-count-distinct postgresql-18-omnisketch postgresql-18-ddsketch postgresql-18-vasco postgresql-18-pgxicor postgresql-18-weighted-statistics postgresql-18-tdigest postgresql-18-first-last-agg postgresql-18-extra-window-functions postgresql-18-floatvec postgresql-18-aggs-for-vecs postgresql-18-aggs-for-arrays postgresql-18-pg-csv postgresql-18-pg-arraymath postgresql-18-pg-math postgresql-18-random postgresql-18-base36 postgresql-18-base62 postgresql-18-pg-base58 postgresql-18-pg-financial postgresql-18-convert
RUN apt-get install -y postgresql-18-repack postgresql-18-pg-rewrite postgresql-18-squeeze postgresql-18-dirtyread postgresql-18-pgfincore postgresql-18-pg-cooldown postgresql-18-ddlx postgresql-18-pglinter postgresql-18-prioritize postgresql-18-pg-checksums postgresql-18-pg-readonly postgresql-18-pgdd postgresql-18-pg-permissions postgresql-18-auto-failover postgresql-18-pg-catcheck postgresql-18-preprepare postgresql-18-pg-upless postgresql-18-pgcozy postgresql-18-pg-orphaned postgresql-18-pg-crash postgresql-18-pg-cheat-funcs postgresql-18-pg-fio postgresql-18-pg-savior postgresql-18-pg-safeupdate postgresql-18-pg-drop-events postgresql-18-tablelog
RUN apt-get install -y postgresql-18-pg-profile postgresql-18-pg-tracing postgresql-18-show-plans postgresql-18-pg-stat-kcache postgresql-18-pg-stat-monitor postgresql-18-pg-qualstats postgresql-18-pg-store-plan postgresql-18-pg-track-settings postgresql-18-pg-wait-sampling postgresql-18-pgsentinel postgresql-18-system-stats postgresql-18-pg-meta postgresql-18-pgnodemx postgresql-18-pg-sqlog postgresql-18-bgw-replstatus postgresql-18-pgmeminfo postgresql-18-toastinfo postgresql-18-pg-explain-ui postgresql-18-pg-relusage postgresql-18-pagevis postgresql-18-powa
RUN apt-get install -y postgresql-18-passwordcheck-cracklib postgresql-18-supautils postgresql-18-pgsodium postgresql-18-vault postgresql-18-pg-session-jwt postgresql-18-pg-anon postgresql-18-pgsmcrypto postgresql-18-enigma postgresql-18-pgaudit postgresql-18-pgauditlogtofile postgresql-18-pg-auditor postgresql-18-logerrors postgresql-18-pg-auth-mon postgresql-18-pg-jobmon postgresql-18-credcheck postgresql-18-pgcryptokey postgresql-18-login-hook postgresql-18-set-user postgresql-18-snakeoil postgresql-18-pgextwlist postgresql-18-sslutils postgresql-18-noset
RUN apt-get install -y postgresql-18-wrappers postgresql-18-mysql-fdw postgresql-18-tds-fdw postgresql-18-etcd-fdw postgresql-18-redis-fdw postgresql-18-pg-redis-pubsub postgresql-18-kafka-fdw postgresql-18-firebird-fdw postgresql-18-aws-s3 postgresql-18-log-fdw
RUN apt-get install -y postgresql-18-documentdb postgresql-18-orafce postgresql-18-pgtt postgresql-18-session-variable postgresql-18-pg-statement-rollback postgresql-18-pgmemcache
RUN apt-get install -y postgresql-18-pglogical postgresql-18-pglogical-ticker postgresql-18-pg-failover-slots postgresql-18-db-migrator postgresql-18-pgactive postgresql-18-wal2json postgresql-18-decoderbufs postgresql-18-decoder-raw postgresql-18-mimeo postgresql-18-pg-bulkload

# Remove pgqd service (pgq daemon) - will be managed manually if needed
RUN rm -f /lib/systemd/system/pgqd.service \
    && rm -rf /etc/systemd/system/pgqd.service /etc/systemd/system/pgqd.service.d \
              /etc/systemd/system/*.wants/pgqd* 2>/dev/null || true

# Cleanup and remove policy-rc.d (restore normal service behavior)
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && rm -f /usr/sbin/policy-rc.d
