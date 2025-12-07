#!/bin/sh

# List of service names that should not be started by deb install/update
STOP_SERVICES="nginx loki dnsmasq haproxy keepalived docker vector minio etcd postgresql pgbouncer patroni redis-server postgresql-common postgresql-19 postgresql-18 postgresql-17 postgresql-16 postgresql-15 postgresql-14 postgresql-13 postgresql-12 postgresql-11 postgresql-10"

# Check if the service is in the STOP_SERVICES list
for SERVICE in $STOP_SERVICES; do
  if [ "$1" = "$SERVICE" ]; then
    exit 101
  fi
done

exit 0