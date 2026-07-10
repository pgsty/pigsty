-include .env
export

default: up view

DOCKER_IMAGE_DIR=/tmp/docker/

up: view
	docker compose up -d

view:
	@echo "visit $(PUBLIC_ORIGIN) or http://10.10.10.10:$(TEABLE_PORT)"
	@echo "persistent assets: $(TEABLE_DATA)"

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
	docker save ghcr.io/teableio/teable | gzip -c -9 > $(DOCKER_IMAGE_DIR)/teable.tgz

tarball: save
	tar -cvf /tmp/teable.tgz -C /tmp/docker teable

load:
	cat $(DOCKER_IMAGE_DIR)/teable.tgz | gzip -d -c - | docker load

.PHONY: default up view log info down stop clean pull save tarball load
