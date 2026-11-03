SHELL := /bin/bash -e -o pipefail

default: up view

bootstrap:
	docker compose --profile bootstrap run --rm kong-migration

up: view
	docker compose up -d kong

view:
	@docker compose config --format json | jq -r '.services.kong.ports[] | select(.host_ip == "127.0.0.1") | "admin url: http://127.0.0.1:\(.published) (use an SSH tunnel for remote administration)"'

ui:
	@port="$$(docker compose config --format json | jq -er '.services.kong.ports[] | select(.host_ip == "127.0.0.1") | .published')"; \
	docker run --init --name swagger -d -p 127.0.0.1:8882:8080 -e "API_URL=http://127.0.0.1:$$port" swaggerapi/swagger-ui

rmui:
	docker rm -f swagger

log:
	docker logs -f kong

info:
	docker inspect kong | jq

stop:
	docker stop kong;

clean:
	docker stop kong; docker rm -f kong


pull:
	docker compose --profile bootstrap pull

rmi:
	docker rmi $$(docker compose config --images | sort -u)

save:
	mkdir -p /tmp/docker
	@images="$$(docker compose config --images | sort -u)"; test -n "$$images"; \
	archive_path="/tmp/docker/kong.tgz"; \
	archive_tmp=$$(mktemp "$$archive_path.tmp.XXXXXX"); \
	trap 'rm -f -- "$$archive_tmp"' EXIT; \
	docker save $$images | gzip -9 -c > "$$archive_tmp"; \
	mv -f -- "$$archive_tmp" "$$archive_path"; \
	trap - EXIT

load:
	cat /tmp/docker/kong.tgz | gzip -d -c - | docker load

.PHONY: default bootstrap up view ui rmui log info stop clean pull rmi save load
