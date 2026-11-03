SHELL := /bin/bash -e -o pipefail

default: up view

DOCKER_IMAGE_DIR=/tmp/docker/immich
up: view
	docker compose up -d

view:
	@docker compose config --format json | jq -r '.services["immich-server"] as $$app | "visit http://photo.pigsty or http://10.10.10.10:\($$app.ports[] | select(.target == 2283) | .published)", "image: \($$app.image)", "media: \($$app.volumes[] | select(.target == "/data") | .source)", "vector extension: \($$app.environment.DB_VECTOR_EXTENSION // "default")", "redis: \($$app.environment.REDIS_HOSTNAME):\($$app.environment.REDIS_PORT)" | split("$$$$") | join("$$")'

log logs:
	docker compose logs -f

info:
	docker compose ps

down: stop
stop:
	docker compose down

start:
	docker compose start

restart:
	docker compose restart

pull:
	docker compose pull

clean:
	docker compose rm
	@echo "dont' forget to remove the immich database and /data/immich media files if needed"

save:
	@config="$$(docker compose config --format json)"; \
	server="$$(printf '%s' "$$config" | jq -er '.services["immich-server"].image')"; \
	ml="$$(printf '%s' "$$config" | jq -er '.services["immich-machine-learning"].image')"; \
	cache="$$(printf '%s' "$$config" | jq -er '.services.redis.image')"; \
	mkdir -p "$(DOCKER_IMAGE_DIR)"; \
	archive_path="$(DOCKER_IMAGE_DIR)/immich-server.tgz"; \
	archive_tmp=$$(mktemp "$$archive_path.tmp.XXXXXX"); \
	trap 'rm -f -- "$$archive_tmp"' EXIT; \
	docker save "$$server" | gzip -c -9 > "$$archive_tmp"; \
	mv -f -- "$$archive_tmp" "$$archive_path"; \
	trap - EXIT; \
	archive_path="$(DOCKER_IMAGE_DIR)/immich-machine-learning.tgz"; \
	archive_tmp=$$(mktemp "$$archive_path.tmp.XXXXXX"); \
	trap 'rm -f -- "$$archive_tmp"' EXIT; \
	docker save "$$ml" | gzip -c -9 > "$$archive_tmp"; \
	mv -f -- "$$archive_tmp" "$$archive_path"; \
	trap - EXIT; \
	archive_path="$(DOCKER_IMAGE_DIR)/valkey.tgz"; \
	archive_tmp=$$(mktemp "$$archive_path.tmp.XXXXXX"); \
	trap 'rm -f -- "$$archive_tmp"' EXIT; \
	docker save "$$cache" | gzip -c -9 > "$$archive_tmp"; \
	mv -f -- "$$archive_tmp" "$$archive_path"; \
	trap - EXIT

tarball: save
	tar -cvf /tmp/immich.tgz -C /tmp/docker immich

load:
	cat $(DOCKER_IMAGE_DIR)/immich-server.tgz | gzip -d -c - | docker load
	cat $(DOCKER_IMAGE_DIR)/immich-machine-learning.tgz | gzip -d -c - | docker load
	cat $(DOCKER_IMAGE_DIR)/valkey.tgz | gzip -d -c - | docker load

.PHONY: default up view log logs info down stop start restart pull clean save tarball load
