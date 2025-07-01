default: up view

DOCKER_IMAGE_DIR=/tmp/docker/

up: view
	docker compose up -d

view:
	cat .env

log:
	docker compose logs -f

info:
	docker compose ps

down: stop
stop:
	docker compose down

clean:
	docker compose rm
	sudo rm -rf volumes/app;
	@echo "dont' forget to nuke the teable database in postgres"

pull:
	docker compose pull

save:
	mkdir -p $(DOCKER_IMAGE_DIR)
	docker save ghcr.io/teableio/teable | gzip -c -9 > $(DOCKER_IMAGE_DIR)/teable.tgz

tarball: save
	tar -cvf /tmp/teable.tgz -C /tmp/docker teable

load:
	cat $(DOCKER_IMAGE_DIR)/teable.tgz | gzip -d -c - | docker load
