SHELL := /bin/bash -e -o pipefail

default: up view

up: data view
	docker compose up -d

data:
	@path="$$(docker compose config --format json | jq -er '.services.silo.volumes[] | select(.type == "bind" and .target == "/data") | .source | split("$$$$") | join("$$")')"; sudo mkdir -p "$$path"

run: up

view:
	@docker compose config --format json | jq -r '.services.silo.ports as $$ports | "API: http://10.10.10.10:\($$ports[] | select(.target == 9000) | .published); console: http://10.10.10.10:\($$ports[] | select(.target == 9001) | .published)"'
	@echo "Credentials are configured in .env; change the defaults before production use."

log:
	docker compose logs -f silo

info:
	docker compose ps --format json silo | jq

health:
	docker compose exec -T silo silo healthcheck ready
	@port="$$(docker compose config --format json | jq -er '.services.silo.ports[] | select(.target == 9001) | .published')"; curl -fsS -o /dev/null "http://127.0.0.1:$$port/"

stop:
	docker compose stop

clean:
	docker compose down

pull:
	docker compose pull

rmi:
	docker rmi $$(docker compose config --images)

save:
	mkdir -p /tmp/docker
	@images="$$(docker compose config --images)"; test -n "$$images"; \
	archive_path="/tmp/docker/silo.tgz"; \
	archive_tmp=$$(mktemp "$$archive_path.tmp.XXXXXX"); \
	trap 'rm -f -- "$$archive_tmp"' EXIT; \
	docker save $$images | gzip -9 -c > "$$archive_tmp"; \
	mv -f -- "$$archive_tmp" "$$archive_path"; \
	trap - EXIT

load:
	cat /tmp/docker/silo.tgz | gzip -d -c - | docker load

.PHONY: default up data run view log info health stop clean pull rmi save load
