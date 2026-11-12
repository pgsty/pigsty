#==============================================================#
# File      :   Dockerfile
# Desc      :   Pigsty Docker Image based on Debian 13 (Trixie)
# Ctime     :   2025-01-27
# Mtime     :   2026-11-12
# License   :   Apache-2.0 @ https://pigsty.io/docs/about/license
# Copyright :   2018-2025  Ruohang Feng / Vonng (rh@vonng.com)
#==============================================================#
FROM debian:13.7@sha256:9c6e381421d0f48d1b8133e573f33c185ee16cbf505eda9c4a8a4791b25ea8a6

ARG VERSION=4.6.0
ARG PIG_VERSION=1.11.0

LABEL maintainer="Ruohang Feng <rh@vonng.com>"
LABEL org.opencontainers.image.title="Pigsty"
LABEL org.opencontainers.image.description="Pigsty - PostgreSQL in Great STYle"
LABEL org.opencontainers.image.url="https://pigsty.io"
LABEL org.opencontainers.image.source="https://github.com/pgsty/pigsty"
LABEL org.opencontainers.image.version="v${VERSION}"

ENV container=docker \
    DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PIGSTY_VERSION=v${VERSION}

#--------------------------------------------------------------#
# System Setup
#--------------------------------------------------------------#
# Create postgres user/group with fixed UID/GID=543
RUN groupadd -g 543 postgres && useradd -u 543 -g 543 -m -s /bin/bash postgres

# Install systemd and essential packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    systemd systemd-sysv dbus dbus-user-session \
    openssh-server openssh-client sudo \
    locales ca-certificates curl wget less \
    vim git jq lz4 make bash lsof rsync ncdu \
    python3 procps iproute2 net-tools iputils-ping \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#--------------------------------------------------------------#
# Systemd Configuration for Container
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

# Mask services that cause issues in containers
RUN systemctl mask \
    dev-hugepages.mount \
    sys-fs-fuse-connections.mount \
    systemd-update-utmp.service \
    console-getty.service

#--------------------------------------------------------------#
# Locale and Timezone
#--------------------------------------------------------------#
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen en_US.UTF-8 \
    && ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo "${TZ}" > /etc/timezone

#--------------------------------------------------------------#
# SSH Configuration
#--------------------------------------------------------------#
RUN mkdir -p /run/sshd /root/.ssh \
    && chmod 700 /root/.ssh \
    && ssh-keygen -A \
    && sed -i 's/#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && systemctl enable ssh

# Generate SSH keypair and configure passwordless localhost access
RUN ssh-keygen -t rsa -b 2048 -N '' -f /root/.ssh/id_rsa \
    && cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys \
    && chmod 600 /root/.ssh/authorized_keys \
    && printf 'Host *\n    StrictHostKeyChecking no\n    UserKnownHostsFile /dev/null\n' >> /etc/ssh/ssh_config

#--------------------------------------------------------------#
# Sudo and Root Password
#--------------------------------------------------------------#
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/nopasswd \
    && chmod 440 /etc/sudoers.d/nopasswd \
    && echo 'root:pigsty' | chpasswd

#--------------------------------------------------------------#
# Install pig CLI and Initialize Pigsty
#--------------------------------------------------------------#
RUN echo "deb [trusted=yes] https://repo.pigsty.cc/apt/infra/ generic main" \
    > /etc/apt/sources.list.d/pigsty.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends "pig=${PIG_VERSION}-*" \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Use the source archive prepared from this checkout by `make source`.
ADD pigsty.tgz /root/
WORKDIR /root/pigsty

# Check the source version, install Ansible, and generate the container inventory.
RUN test "$(sed -n 's/^PIGSTY_VERSION=//p' bootstrap)" = "${PIGSTY_VERSION%%-*}" \
    && pig sty boot \
    && pig sty conf -c docker --ip 127.0.0.1

RUN mkdir -p /data
VOLUME ["/data"]
EXPOSE 22 80 443 5432
STOPSIGNAL SIGRTMIN+3
CMD ["/lib/systemd/systemd"]
