SHELL := /bin/bash -e -o pipefail

default: up

up:
	docker compose up -d

run: up

view:
	@url=$$(docker compose config --format json | python3 -c 'import json,sys; s=json.load(sys.stdin)["services"]["pg_exporter"]; p=s["ports"][0]; h=p.get("host_ip") or "127.0.0.1"; h="127.0.0.1" if h=="0.0.0.0" else "::1" if h=="::" else h; h="["+h+"]" if ":" in h else h; print("http://"+h+":"+str(p["published"])+s["environment"].get("PG_EXPORTER_TELEMETRY_PATH", "/metrics").replace("$$$$", "$$"))'); curl -fsS "$$url"

log:
	docker logs -f pg_exporter

info:
	docker inspect pg_exporter | jq

stop:
	docker stop pg_exporter;

clean:
	docker stop pg_exporter; docker rm -f pg_exporter

pull:
	docker compose pull

rmi:
	docker rmi $$(docker compose config --images)

save:
	mkdir -p /tmp/docker
	@images="$$(docker compose config --images)"; test -n "$$images"; \
	archive_path="/tmp/docker/pg_exporter.tgz"; \
	archive_tmp=$$(mktemp "$$archive_path.tmp.XXXXXX"); \
	trap 'rm -f -- "$$archive_tmp"' EXIT; \
	docker save $$images | gzip -9 -c > "$$archive_tmp"; \
	mv -f -- "$$archive_tmp" "$$archive_path"; \
	trap - EXIT

load:
	cat /tmp/docker/pg_exporter.tgz | gzip -d -c - | docker load

.PHONY: default up run view log info stop clean pull rmi save load
