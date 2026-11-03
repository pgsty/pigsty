SHELL := /bin/bash -e -o pipefail

default: up view

up: view
	docker compose up -d

run: up

view:
	@docker compose config --format json | jq -r '.services.pgweb.ports[] | select(.target == 8081) | "visit http://cli.pigsty or http://10.10.10.10:\(.published)"'
	@echo "example url: postgres://dbuser_meta:DBUser.Meta@10.10.10.10:5432/meta?sslmode=disable"

log:
	docker logs -f pgweb

info:
	docker inspect pgweb | jq

stop:
	docker stop pgweb;

clean:
	docker stop pgweb; docker rm -f pgweb

pull:
	docker compose pull

rmi:
	docker rmi $$(docker compose config --images)

save:
	mkdir -p /tmp/docker
	@images="$$(docker compose config --images)"; test -n "$$images"; \
	archive_path="/tmp/docker/pgweb.tgz"; \
	archive_tmp=$$(mktemp "$$archive_path.tmp.XXXXXX"); \
	trap 'rm -f -- "$$archive_tmp"' EXIT; \
	docker save $$images | gzip -9 -c > "$$archive_tmp"; \
	mv -f -- "$$archive_tmp" "$$archive_path"; \
	trap - EXIT

load:
	cat /tmp/docker/pgweb.tgz | gzip -d -c - | docker load

.PHONY: default up run view log info stop clean pull rmi save load
