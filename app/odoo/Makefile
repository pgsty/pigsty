SHELL := /bin/bash -e -o pipefail

default: init
	$(MAKE) up view

# init odoo dir & database schema
init: dir
	docker compose --profile init up --abort-on-container-exit --exit-code-from odoo-init odoo-init
dir:
	@set -e; paths="$$(docker compose config --format json | jq -er '[.services.odoo.volumes[] | select(.target == "/var/lib/odoo" or .target == "/mnt/extra-addons")] | if length == 2 and all(.[]; .type == "bind" and (.source | contains("\n") | not)) then .[].source | split("$$$$") | join("$$") else error("Odoo requires two bind directories without newlines") end')"; \
	printf '%s\n' "$$paths" | while IFS= read -r path; do mkdir -p "$$path"; chown 100:101 "$$path"; done
view:
	@docker compose config --format json | jq -r '.services.odoo.ports[] | select(.target == 8069) | "visit http://odoo.pigsty (published HTTP port: \(.published))"'

# administration
up:
	docker compose up -d odoo
down:
	docker compose down
stop:
	docker compose stop
start:
	docker compose start
restart:
	docker compose restart
pause:
	docker compose pause
resume:
	docker compose unpause
pull:
	docker compose pull
rm:
	docker compose rm
logs:
	docker compose logs -f
port:
	docker compose port odoo 8069
conf:
	docker compose config
info:
	docker inspect odoo | jq


save:
	mkdir -p /tmp/docker
	@images="$$(docker compose config --images)"; test -n "$$images"; \
	archive_path="/tmp/docker/odoo.tgz"; \
	archive_tmp=$$(mktemp "$$archive_path.tmp.XXXXXX"); \
	trap 'rm -f -- "$$archive_tmp"' EXIT; \
	docker save $$images | gzip -9 -c > "$$archive_tmp"; \
	mv -f -- "$$archive_tmp" "$$archive_path"; \
	trap - EXIT
load:
	cat /tmp/docker/odoo.tgz | gzip -d -c - | docker load

.PHONY: default init dir view up down stop start restart pause resume pull rm logs port conf info save load
