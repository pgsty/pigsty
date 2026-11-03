#!/bin/sh
set -e

# Generate SHA1 base64 hash for Envoy basic auth user list
PASSWORD_HASH=$(printf '%s' "${DASHBOARD_PASSWORD}" | openssl sha1 -binary | openssl base64)
export DASHBOARD_BASIC_AUTH="${DASHBOARD_USERNAME}:{SHA}${PASSWORD_HASH}"

echo "Generating Envoy configuration..."

# Values use explicit YAML/Lua quoting and are substituted exactly once.
# The renderer compares UTF-8 byte sequences; do not use locale collation.
LC_ALL=C awk -v gateway=envoy -f /etc/gateway/render-template.awk \
    /etc/envoy/lds.template.yaml > /etc/envoy/lds.yaml

if [ -n "$SUPABASE_SECRET_KEY" ] && \
   [ -n "$SUPABASE_PUBLISHABLE_KEY" ] && \
   [ -n "$SERVICE_ROLE_KEY_ASYMMETRIC" ] && \
   [ -n "$ANON_KEY_ASYMMETRIC" ]; then
  echo "Envoy sb_ key translation enabled"
else
  echo "Envoy running in legacy API key mode (sb_ keys disabled)"
fi

echo "Envoy configuration generated successfully"
echo "Starting Envoy..."

# Start Envoy
exec envoy -c /etc/envoy/envoy.yaml "$@"
