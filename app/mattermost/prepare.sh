#!/usr/bin/env bash
# Resolve bind mounts exactly as Compose does, including .env and shell overrides.
set -euo pipefail

docker compose config --format json |
  python3 -c '
import json, os, sys
try:
    config = json.load(sys.stdin)
except json.JSONDecodeError:
    sys.exit("Could not read the resolved Mattermost Compose configuration")
targets = {
    "/mattermost/config", "/mattermost/data", "/mattermost/logs",
    "/mattermost/plugins", "/mattermost/client/plugins", "/mattermost/bleve-indexes",
}
paths = sorted({
    os.path.realpath(mount["source"].replace("$$", "$"))
    for mount in config["services"]["mattermost"].get("volumes", [])
    if mount["type"] == "bind" and mount["target"] in targets
})
forbidden = {
    "/", "/data", "/home", "/root", "/opt", "/var", "/tmp", "/etc", "/usr",
    "/var/lib", "/var/log",
    os.path.realpath(os.getcwd()), os.path.realpath(os.path.expanduser("~")),
}
for path in paths:
    if path in forbidden or os.path.dirname(path) == "/":
        sys.exit("Refusing to change ownership of broad Mattermost bind path: " + path)
# Validate every path before emitting any work. NUL separators preserve spaces.
for path in paths:
    sys.stdout.write(path + "\0")
' |
  while IFS= read -r -d '' directory; do
    mkdir -p -- "$directory"
    chown -R 2000:2000 -- "$directory"
  done
