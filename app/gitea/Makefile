SHELL := /bin/bash -e -o pipefail

default: up view

up: view
	docker compose up -d

view:
	@echo "visit http://git.pigsty  or  http://10.10.10.10:8889"

log:
	docker logs -f gitea

info:
	docker inspect gitea | jq

# prepare external pg
pg:
	@echo "pg_users:     { name: dbuser_gitea , password: DBUser.Gitea, roles: [ dbrole_admin ] }"
	@echo "pg_databases: { name: gitea, owner: dbuser_gitea, comment: gitea primary database }"
	@echo "bin/pgsql-user pg-meta dbuser_gitea ; bin/pgsql-db pg-meta gitea"

stop:
	docker stop gitea;

clean:
	docker stop gitea; docker rm -f gitea

pull:
	docker compose pull

rmi:
	docker rmi $$(docker compose config --images)

rmdata:
	rm -rf /data/gitea

save:
	mkdir -p /tmp/docker
	@images="$$(docker compose config --images)"; test -n "$$images"; \
	archive_path="/tmp/docker/gitea.tgz"; \
	archive_tmp=$$(mktemp "$$archive_path.tmp.XXXXXX"); \
	trap 'rm -f -- "$$archive_tmp"' EXIT; \
	docker save $$images | gzip -9 -c > "$$archive_tmp"; \
	mv -f -- "$$archive_tmp" "$$archive_path"; \
	trap - EXIT

load:
	cat /tmp/docker/gitea.tgz | gzip -d -c - | docker load

.PHONY: default up view log info pg stop clean pull rmi rmdata save load
