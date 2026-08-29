SHELL := /bin/bash -e -o pipefail

default: up view

up: view
	docker compose up -d

run: up

view:
	@echo "visit http://mtbs.pigsty  or  http://10.10.10.10:9004"

log:
	docker logs -f metabase

info:
	docker inspect metabase | jq

stop:
	docker stop metabase;

clean:
	docker stop metabase; docker rm -f metabase

pull:
	docker compose pull

rmi:
	docker rmi $$(docker compose config --images)

save:
	mkdir -p /tmp/docker
	@images="$$(docker compose config --images)"; test -n "$$images"; \
	archive_path="/tmp/docker/metabase.tgz"; \
	archive_tmp=$$(mktemp "$$archive_path.tmp.XXXXXX"); \
	trap 'rm -f -- "$$archive_tmp"' EXIT; \
	docker save $$images | gzip -9 -c > "$$archive_tmp"; \
	mv -f -- "$$archive_tmp" "$$archive_path"; \
	trap - EXIT

load:
	cat /tmp/docker/metabase.tgz | gzip -d -c - | docker load

.PHONY: default up run view log info stop clean pull rmi save load
