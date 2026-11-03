SHELL := /bin/bash -e -o pipefail

default: up view

up: view
	docker compose up -d

run: up

view:
	@echo "visit http://noco.pigsty  or  http://10.10.10.10:9003"

log:
	docker logs -f nocodb

info:
	docker inspect nocodb | jq

stop:
	docker stop nocodb;

clean:
	docker stop nocodb; docker rm -f nocodb

pull:
	docker compose pull

rmi:
	docker rmi $$(docker compose config --images)

save:
	mkdir -p /tmp/docker
	@images="$$(docker compose config --images)"; test -n "$$images"; \
	archive_path="/tmp/docker/nocodb.tgz"; \
	archive_tmp=$$(mktemp "$$archive_path.tmp.XXXXXX"); \
	trap 'rm -f -- "$$archive_tmp"' EXIT; \
	docker save $$images | gzip -9 -c > "$$archive_tmp"; \
	mv -f -- "$$archive_tmp" "$$archive_path"; \
	trap - EXIT

load:
	cat /tmp/docker/nocodb.tgz | gzip -d -c - | docker load

.PHONY: default up run view log info stop clean pull rmi save load
