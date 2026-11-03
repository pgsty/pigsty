SHELL := /bin/bash -e -o pipefail

default: up view

up: view
	docker compose up -d

# run with local data dir & external pg
run: up

view:
	@echo "visit http://ddl.pigsty  or  http://10.10.10.10:8887"

log:
	docker logs -f bytebase

info:
	docker inspect bytebase | jq

# prepare external pg
pg:
	@echo "pg_users:     { name: dbuser_bytebase , password: DBUser.Bytebase, roles: [ dbrole_admin ] }"
	@echo "pg_databases: { name: bytebase, owner: dbuser_bytebase, comment: bytebase primary database }"
	@echo "bin/pgsql-user pg-meta dbuser_bytebase ; bin/pgsql-db pg-meta bytebase"

stop:
	docker stop bytebase;

clean:
	docker stop bytebase; docker rm -f bytebase

pull:
	docker compose pull

rmi:
	docker rmi $$(docker compose config --images)

save:
	mkdir -p /tmp/docker
	@images="$$(docker compose config --images)"; test -n "$$images"; \
	archive_path="/tmp/docker/bytebase.tgz"; \
	archive_tmp=$$(mktemp "$$archive_path.tmp.XXXXXX"); \
	trap 'rm -f -- "$$archive_tmp"' EXIT; \
	docker save $$images | gzip -9 -c > "$$archive_tmp"; \
	mv -f -- "$$archive_tmp" "$$archive_path"; \
	trap - EXIT

load:
	cat /tmp/docker/bytebase.tgz | gzip -d -c - | docker load

.PHONY: default up run view log info pg stop clean pull rmi save load
