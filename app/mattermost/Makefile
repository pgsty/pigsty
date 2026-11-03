SHELL := /bin/bash -e -o pipefail

default: up

up: mkdir
	docker compose up -d

mkdir:
	bash ./prepare.sh

view:
	@echo "visit http://mm.pigsty  or  http://10.10.10.10:8065"

log:
	docker compose logs -f

info:
	docker inspect mattermost | jq

health:
	docker compose exec -T mattermost /mattermost/bin/mmctl system status --local

stop:
	docker stop mattermost;

clean:
	docker stop mattermost; docker rm -f mattermost

edit:
	vi .env

restart:
	docker compose restart

pull:
	docker compose pull

rmi:
	docker rmi $$(docker compose config --images)

save:
	mkdir -p /tmp/docker
	@images="$$(docker compose config --images)"; test -n "$$images"; \
	archive_path="/tmp/docker/mattermost.tgz"; \
	archive_tmp=$$(mktemp "$$archive_path.tmp.XXXXXX"); \
	trap 'rm -f -- "$$archive_tmp"' EXIT; \
	docker save $$images | gzip -9 -c > "$$archive_tmp"; \
	mv -f -- "$$archive_tmp" "$$archive_path"; \
	trap - EXIT

load:
	cat /tmp/docker/mattermost.tgz | gzip -d -c - | docker load

.PHONY: default up mkdir view log info health stop clean edit restart pull rmi save load
