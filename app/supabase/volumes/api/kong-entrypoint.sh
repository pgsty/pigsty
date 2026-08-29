#!/bin/sh
set -e
# Render values as YAML/Lua string literals, preserving quotes, backslashes,
# Unicode, and literal template-looking text in credentials.

# The renderer compares UTF-8 byte sequences; do not use locale collation.
LC_ALL=C awk -v gateway=kong -f /etc/gateway/render-template.awk \
    /home/kong/temp.yml > "$KONG_DECLARATIVE_CONFIG"

# Remove empty key-auth credentials (unconfigured opaque keys)
sed -i '/^[[:space:]]*- key: ""[[:space:]]*$/d' "$KONG_DECLARATIVE_CONFIG"

exec /entrypoint.sh kong docker-start
