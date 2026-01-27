#==============================================================#
# File      :   Dockerfile
# Desc      :   Pigsty Docker Image based on Debian 13 (Trixie)
# Ctime     :   2026-01-27
# Mtime     :   2026-01-27
# License   :   Apache-2.0 @ https://pigsty.io/docs/about/license
# Copyright :   2018-2026  Ruohang Feng / Vonng (rh@vonng.com)
#==============================================================#
#
# Two build targets available:
#
#   base: Pigsty initialized, ready for ./configure && ./deploy.yml
#   full: Pigsty fully deployed, ready to use out of the box
#
# Build Commands:
#   docker build -t pigsty:v4.0.0 .                        # base
#   docker build --target full -t pigsty-full:v4.0.0 .     # full
#
# Run Command:
#   docker run -d --privileged --name pigsty \
#     --cgroupns=host -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
#     -p 2222:22 -p 8080:80 -p 5432:5432 pigsty:v4.0.0
#
#==============================================================#


#--------------------------------------------------------------#
# Stage 1: Base Image
#--------------------------------------------------------------#
# This stage creates a ready-to-deploy Pigsty environment:
#   - Debian 13 (Trixie) with SystemD enabled
#   - SSH server configured (root:pigsty)
#   - pig CLI installed, pigsty source initialized
#   - Ansible and dependencies installed via `pig sty boot`
#   - Default docker config template applied
#
# After running this image, execute:
#   ./configure -c docker -i 127.0.0.1
#   ./deploy.yml
#--------------------------------------------------------------#
FROM debian:trixie AS base

LABEL maintainer="Ruohang Feng <rh@vonng.com>"
LABEL org.opencontainers.image.title="Pigsty"
LABEL org.opencontainers.image.description="Battery-Included PostgreSQL Distribution"
LABEL org.opencontainers.image.url="https://pigsty.io"
LABEL org.opencontainers.image.source="https://github.com/pgsty/pigsty"
LABEL org.opencontainers.image.version="4.0.0"

ENV container=docker \
    DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PIGSTY_VERSION=v4.0.0

#--------------------------------------------------------------#
# Install SystemD and essential packages
#--------------------------------------------------------------#
# Core: systemd, dbus (required for systemd in container)
# SSH:  openssh-server/client, sudo
# I18N: locales, ca-certificates
# Tool: curl, wget, vim, git, jq, lz4, unzip, bzip2, pv
#       make, patch, bash, lsof, rsync, ncdu
# Net:  procps, iproute2, net-tools, iputils-ping
# Python: python3 (required by ansible, pip/venv not needed with uv)
#--------------------------------------------------------------#
RUN apt-get update && apt-get install -y --no-install-recommends \
    systemd systemd-sysv dbus dbus-user-session \
    openssh-server openssh-client sudo \
    locales ca-certificates curl wget \
    vim git jq lz4 make bash lsof rsync ncdu \
    python3 procps iproute2 net-tools iputils-ping \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#--------------------------------------------------------------#
# Configure SystemD for container environment
#--------------------------------------------------------------#
# Remove unnecessary systemd units that don't work in containers
# Keep only essential services for a minimal bootable system
#--------------------------------------------------------------#
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

RUN systemctl mask \
    dev-hugepages.mount \
    sys-fs-fuse-connections.mount \
    systemd-update-utmp.service \
    systemd-tmpfiles-setup.service \
    console-getty.service

#--------------------------------------------------------------#
# Configure locale, timezone, SSH, sudo
#--------------------------------------------------------------#
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen en_US.UTF-8 \
    && ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo "${TZ}" > /etc/timezone

RUN mkdir -p /run/sshd /root/.ssh \
    && chmod 700 /root/.ssh \
    && ssh-keygen -A \
    && sed -i 's/#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && systemctl enable ssh

RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/nopasswd \
    && chmod 440 /etc/sudoers.d/nopasswd

RUN echo 'root:pigsty' | chpasswd

#--------------------------------------------------------------#
# Install pig CLI from Pigsty APT repository
#--------------------------------------------------------------#
RUN echo "deb [trusted=yes] https://repo.pigsty.cc/apt/infra/ generic main" \
    > /etc/apt/sources.list.d/pigsty.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends pig \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

#--------------------------------------------------------------#
# Initialize Pigsty with pig CLI
#--------------------------------------------------------------#
# pig sty init: download and extract pigsty source to ~/pigsty
# pig sty boot: install ansible and python dependencies
# cp docker.yml: use docker config template as default config
#--------------------------------------------------------------#
RUN pig sty init -v ${PIGSTY_VERSION} \
    && pig sty boot \
    && pig sty conf -c docker -i 127.0.0.1

# Enable profile.d scripts in interactive bash sessions
RUN printf '\n# Load /etc/profile.d scripts\nif [ -d /etc/profile.d ]; then\n  for i in /etc/profile.d/*.sh; do\n    if [ -r "$i" ]; then\n      . "$i"\n    fi\n  done\nfi\n' >> /root/.bashrc

#--------------------------------------------------------------#
# Finalize base image
#--------------------------------------------------------------#
RUN mkdir -p /data
WORKDIR /root/pigsty
VOLUME ["/sys/fs/cgroup", "/data"]

# Ports: 22=SSH, 80=HTTP, 443=HTTPS, 5432=PostgreSQL
# Web services (Grafana, etc.) accessed via Nginx reverse proxy
EXPOSE 22 80 443 5432

STOPSIGNAL SIGRTMIN+3
CMD ["/lib/systemd/systemd"]


#--------------------------------------------------------------#
# Stage 2: Full Image (fully deployed)
#--------------------------------------------------------------#
# This stage extends base with a complete Pigsty deployment:
#   - Runs ./configure -c docker -g -i 127.0.0.1
#   - Runs ./deploy.yml to deploy INFRA + ETCD + PGSQL
#   - PostgreSQL 18 running with default databases/users
#   - Grafana, VictoriaMetrics, Nginx, etc. all configured
#
# Use this image for quick demos or testing. Not recommended
# for production due to large image size and fixed config.
#
# Note: Uses ansible local connection (-c local) since SSH
# is not available during docker build (systemd not running)
#--------------------------------------------------------------#
FROM base AS full

# Configure with random passwords and deploy using local connection
# -c local: use local connection instead of SSH (no systemd during build)
RUN cd /root/pigsty \
    && pig sty conf -c docker -g -i 127.0.0.1 \
    && ./deploy.yml -c local
