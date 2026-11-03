SHELL := /bin/bash -e -o pipefail

default: up view

up: view
	docker compose up -d

run: up

ui:
	@port="$$(docker compose config --format json | jq -er '.services.postgrest.ports[0].published')"; \
	docker run --init --name swagger -d -p 127.0.0.1:8883:8080 -e "API_URL=http://127.0.0.1:$$port" swaggerapi/swagger-ui

view:
	@docker compose config --format json | jq -r '.services.postgrest.ports[0] | "visit http://127.0.0.1:\(.published) for API Spec"'

log:
	docker logs -f postgrest

info:
	docker inspect postgrest | jq

stop:
	docker stop postgrest;

clean:
	docker stop postgrest; docker rm -f postgrest

rmui:
	docker rm -f swagger

pull:
	docker compose pull

rmi:
	@images="$$(docker compose config --images)"; test -n "$$images"; docker rmi $$images

save:
	mkdir -p /tmp/docker
	@images="$$(docker compose config --images)"; test -n "$$images"; \
	archive_path="/tmp/docker/postgrest.tgz"; \
	archive_tmp=$$(mktemp "$$archive_path.tmp.XXXXXX"); \
	trap 'rm -f -- "$$archive_tmp"' EXIT; \
	docker save $$images | gzip -9 -c > "$$archive_tmp"; \
	mv -f -- "$$archive_tmp" "$$archive_path"; \
	trap - EXIT

load:
	cat /tmp/docker/postgrest.tgz | gzip -d -c - | docker load

.PHONY: default up run ui rmui view log info stop clean pull rmi save load
