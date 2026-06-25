#!/bin/sh

# List of service names that should not be started by deb install/update
STOP_SERVICES="nginx loki dnsmasq haproxy keepalived docker vector minio etcd postgresql pgbouncer patroni redis-server postgresql-common postgresql-19 postgresql-18 postgresql-17 postgresql-16 postgresql-15 postgresql-14 postgresql-13 postgresql-12 postgresql-11 postgresql-10"

# policy-rc.d is called as either:
#   policy-rc.d [--quiet] <service> <action>
#   policy-rc.d <unit>.service <action>
SERVICE_ID="$1"
[ "$SERVICE_ID" = "--quiet" ] && SERVICE_ID="$2"
SERVICE_ID="${SERVICE_ID%.service}"
SERVICE_ID="${SERVICE_ID%%@*}"

# Check if the service is in the STOP_SERVICES list
for SERVICE in $STOP_SERVICES; do
  if [ "$SERVICE_ID" = "$SERVICE" ]; then
    exit 101
  fi
done

exit 0
