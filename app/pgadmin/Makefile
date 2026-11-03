SHELL := /bin/bash -e -o pipefail

default: up view

up:
	docker compose up -d
	$(MAKE) pass
down:
	docker compose down
run: up
view:
	@echo "visit http://adm.pigsty or the published endpoint below"
	@docker compose port pgadmin 80
	@echo "use the PGADMIN_DEFAULT_EMAIL and PGADMIN_DEFAULT_PASSWORD configured in .env"
log:
	docker logs -f pgadmin
info:
	docker inspect pgadmin | jq
clean:
	docker stop pgadmin; docker rm -f pgadmin
edit:
	vi .env
pull:
	docker compose pull
rmi:
	docker rmi $$(docker compose config --images)
start:
	docker compose start
	$(MAKE) pass
stop:
	docker compose stop
restart:
	docker compose restart
	$(MAKE) pass
exec:
	docker exec -u 0 -it pgadmin /bin/bash

reload: list pass
conf: list pass
pass:
	@set -e; source="$$(docker compose config --format json | jq -er '.services.pgadmin as $$s | $$s.volumes[] | select(.type == "bind" and .target == $$s.environment.PGPASS_FILE) | .source | split("$$$$") | join("$$")')"; \
	docker compose exec -T pgadmin /bin/sh -ec 'dir="/var/lib/pgadmin/storage/$$(printf "%s" "$$PGADMIN_DEFAULT_EMAIL" | tr "@" "_")"; mkdir -p "$$dir"; umask 077; cat > "$$dir/.pgpass"; chmod 600 "$$dir/.pgpass"' < "$$source"
list:
	@set -e; source="$$(docker compose config --format json | jq -er '.services.pgadmin as $$s | $$s.volumes[] | select(.type == "bind" and .target == $$s.environment.PGADMIN_SERVER_JSON_FILE) | .source | split("$$$$") | join("$$")')"; \
	jq -e '.Servers | type == "object"' "$$source" >/dev/null; \
	docker compose exec -T pgadmin /bin/sh -ec 'set --; if [ "$$PGADMIN_REPLACE_SERVERS_ON_STARTUP" = "True" ]; then set -- --replace; fi; exec /venv/bin/python3 /pgadmin4/setup.py load-servers /dev/stdin --user "$$PGADMIN_DEFAULT_EMAIL" "$$@"' < "$$source"

# load pigsty server list manually
servers: list
# load pgpass manually
pgpass: pass


dump: save
save:
	mkdir -p /tmp/docker
	@images="$$(docker compose config --images)"; test -n "$$images"; \
	archive_path="/tmp/docker/pgadmin4.tgz"; \
	archive_tmp=$$(mktemp "$$archive_path.tmp.XXXXXX"); \
	trap 'rm -f -- "$$archive_tmp"' EXIT; \
	docker save $$images | gzip -9 -c > "$$archive_tmp"; \
	mv -f -- "$$archive_tmp" "$$archive_path"; \
	trap - EXIT
load:
	cat /tmp/docker/pgadmin4.tgz | gzip -d -c - | docker load

.PHONY: default up down run view log info clean edit pull start stop restart exec reload conf list pass servers pgpass rmi dump save load
