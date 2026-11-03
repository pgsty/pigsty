#!/usr/bin/env bash
# Build InsForge's required utility hook for the target PostgreSQL installation.
# Run on each DB node after installing the matching PostgreSQL development package,
# and before initializing PostgreSQL with insforge_pg_utils in pg_libs.
set -euo pipefail

PG_CONFIG=${PG_CONFIG:-pg_config}
SOURCE_REV=86f0653c2dd3cbe15dab6fcc34d880d8b1b2ea9f
SOURCE_BASE="https://raw.githubusercontent.com/InsForge/insforge-db/${SOURCE_REV}/postgres/insforge_pg_utils"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root on the PostgreSQL node; this installs a shared library." >&2
  exit 1
fi
for tool in curl make cc patch sha256sum install; do
  command -v "$tool" >/dev/null || { echo "Missing build tool: $tool" >&2; exit 1; }
done
command -v "$PG_CONFIG" >/dev/null || { echo "PG_CONFIG not found: $PG_CONFIG" >&2; exit 1; }
PG_MAJOR=$("$PG_CONFIG" --version | awk '{print $2}' | cut -d. -f1)
case "$PG_MAJOR" in
  15|16|17|18) ;;
  *) echo "Supported PostgreSQL majors: 15-18; found $PG_MAJOR" >&2; exit 1 ;;
esac

BUILD_DIR=$(mktemp -d /tmp/insforge-pg-utils.XXXXXXXX)
mkdir -p "$BUILD_DIR/src"
echo "Source revision: $SOURCE_REV"
echo "Build directory (retained for inspection): $BUILD_DIR"
curl --fail --show-error --silent --location --retry 3 \
  "$SOURCE_BASE/Makefile" -o "$BUILD_DIR/Makefile"
curl --fail --show-error --silent --location --retry 3 \
  "$SOURCE_BASE/src/insforge_pg_utils.c" -o "$BUILD_DIR/src/insforge_pg_utils.c"
(cd "$BUILD_DIR" && sha256sum --check "$SCRIPT_DIR/SHA256SUMS")
patch --directory "$BUILD_DIR" -p1 --forward < "$SCRIPT_DIR/pg16-18.patch"
make -C "$BUILD_DIR" PG_CONFIG="$PG_CONFIG" PG_CFLAGS="-ffile-prefix-map=$BUILD_DIR=."

TARGET_LIBRARY="$("$PG_CONFIG" --pkglibdir)/insforge_pg_utils.so"
if [ -e "$TARGET_LIBRARY" ]; then
  if cmp -s "$BUILD_DIR/insforge_pg_utils.so" "$TARGET_LIBRARY"; then
    echo "The verified library is already installed: $TARGET_LIBRARY"
    exit 0
  fi
  echo "Refusing to overwrite an existing different library: $TARGET_LIBRARY" >&2
  echo "Back it up and plan its replacement/restart explicitly before retrying." >&2
  exit 1
fi
make -C "$BUILD_DIR" install PG_CONFIG="$PG_CONFIG" PG_CFLAGS="-ffile-prefix-map=$BUILD_DIR=."
sha256sum "$TARGET_LIBRARY"
echo "Installed for PostgreSQL $PG_MAJOR. Add insforge_pg_utils to pg_libs before cluster initialization."
