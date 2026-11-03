SHELL := /bin/bash -e -o pipefail

default: up view

DOCKER_IMAGE_DIR=/tmp/docker/

up: view
	docker compose up -d

view:
	@docker compose config --format json | jq -r '.services.teable as $$app | "visit \($$app.environment.PUBLIC_ORIGIN) or http://10.10.10.10:\($$app.ports[] | select(.target == 3000) | .published)", "persistent assets: \($$app.volumes[] | select(.target == "/app/.assets") | .source)" | split("$$$$") | join("$$")'

log:
	docker compose logs -f

info:
	docker compose ps

down: stop
stop:
	docker compose down

clean:
	docker compose down --remove-orphans

pull:
	docker compose pull

save:
	mkdir -p $(DOCKER_IMAGE_DIR)
	@images="$$(docker compose config --images)"; test -n "$$images"; \
	archive_path="$(DOCKER_IMAGE_DIR)/teable.tgz"; \
	archive_tmp=$$(mktemp "$$archive_path.tmp.XXXXXX"); \
	trap 'rm -f -- "$$archive_tmp"' EXIT; \
	docker save $$images | gzip -c -9 > "$$archive_tmp"; \
	mv -f -- "$$archive_tmp" "$$archive_path"; \
	trap - EXIT

tarball: save
	cp $(DOCKER_IMAGE_DIR)/teable.tgz /tmp/teable.tgz

load:
	cat $(DOCKER_IMAGE_DIR)/teable.tgz | gzip -d -c - | docker load

.PHONY: default up view log info down stop clean pull save tarball load
