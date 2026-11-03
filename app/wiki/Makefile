SHELL := /bin/bash -e -o pipefail

default: up view

up: view
	docker compose up -d

view:
	@echo "visit http://wiki.pigsty  or  http://10.10.10.10:9002"

log:
	docker logs -f wiki

info:
	docker inspect wiki | jq

stop:
	docker stop wiki;

clean:
	docker stop wiki; docker rm -f wiki

pull:
	docker compose pull

rmi:
	docker rmi $$(docker compose config --images)

save:
	mkdir -p /tmp/docker
	@images="$$(docker compose config --images)"; test -n "$$images"; \
	archive_path="/tmp/docker/wiki.tgz"; \
	archive_tmp=$$(mktemp "$$archive_path.tmp.XXXXXX"); \
	trap 'rm -f -- "$$archive_tmp"' EXIT; \
	docker save $$images | gzip -9 -c > "$$archive_tmp"; \
	mv -f -- "$$archive_tmp" "$$archive_path"; \
	trap - EXIT

load:
	cat /tmp/docker/wiki.tgz | gzip -d -c - | docker load

.PHONY: default up view log info stop clean pull rmi save load
