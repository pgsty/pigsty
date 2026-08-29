SHELL := /bin/bash -e -o pipefail

default: up view

view:
	@docker compose config --format json | jq -r '.services.electric as $$app | $$app.ports[] | select(.target == ($$app.environment.ELECTRIC_PORT | tonumber)) | "visit http://10.10.10.10:\(.published)"'

# administration
up:
	docker compose up -d
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
log:
	docker compose logs
logs:
	docker compose logs -f
port:
	@port="$$(docker compose config --format json | jq -er '.services.electric.environment.ELECTRIC_PORT')"; docker compose port electric "$$port"
conf:
	docker compose config
info:
	docker inspect electric | jq
save:
	mkdir -p /tmp/docker
	@images="$$(docker compose config --images)"; test -n "$$images"; \
	archive_path="/tmp/docker/electric.tgz"; \
	archive_tmp=$$(mktemp "$$archive_path.tmp.XXXXXX"); \
	trap 'rm -f -- "$$archive_tmp"' EXIT; \
	docker save $$images | gzip -9 -c > "$$archive_tmp"; \
	mv -f -- "$$archive_tmp" "$$archive_path"; \
	trap - EXIT
load:
	cat /tmp/docker/electric.tgz | gzip -d -c - | docker load

.PHONY: default view up down stop start restart pause resume pull rm log logs port conf info save load
