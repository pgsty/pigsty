default: up view

DOCKER_IMAGE_DIR=/tmp/docker/immich
IMMICH_VERSION ?= v3
VALKEY_IMAGE = docker.io/valkey/valkey:9@sha256:4963247afc4cd33c7d3b2d2816b9f7f8eeebab148d29056c2ca4d7cbc966f2d9

up: view
	docker compose up -d

view:
	@echo "visit http://photo.pigsty or http://10.10.10.10:$$(grep -E '^IMMICH_HOST_PORT=' .env | cut -d= -f2)"
	@grep -E '^(IMMICH_VERSION|IMMICH_HOST_PORT|UPLOAD_LOCATION|DB_VECTOR_EXTENSION|REDIS_HOSTNAME|REDIS_PORT)=' .env

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
	mkdir -p $(DOCKER_IMAGE_DIR)
	docker save ghcr.io/immich-app/immich-server:$(IMMICH_VERSION) | gzip -c -9 > $(DOCKER_IMAGE_DIR)/immich-server.tgz
	docker save ghcr.io/immich-app/immich-machine-learning:$(IMMICH_VERSION) | gzip -c -9 > $(DOCKER_IMAGE_DIR)/immich-machine-learning.tgz
	docker save $(VALKEY_IMAGE) | gzip -c -9 > $(DOCKER_IMAGE_DIR)/valkey.tgz

tarball: save
	tar -cvf /tmp/immich.tgz -C /tmp/docker immich

load:
	cat $(DOCKER_IMAGE_DIR)/immich-server.tgz | gzip -d -c - | docker load
	cat $(DOCKER_IMAGE_DIR)/immich-machine-learning.tgz | gzip -d -c - | docker load
	cat $(DOCKER_IMAGE_DIR)/valkey.tgz | gzip -d -c - | docker load

.PHONY: default up view log logs info down stop start restart pull clean save tarball load
