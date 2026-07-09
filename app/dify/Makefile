default: up view

DOCKER_IMAGE_DIR=/tmp/docker/dify
DIFY_VERSION?=1.15.0
DIFY_SANDBOX_VERSION?=0.2.15
DIFY_PLUGIN_DAEMON_VERSION?=0.6.3-local
DIFY_IMAGES= \
	langgenius/dify-api:$(DIFY_VERSION) \
	langgenius/dify-web:$(DIFY_VERSION) \
	langgenius/dify-sandbox:$(DIFY_SANDBOX_VERSION) \
	langgenius/dify-plugin-daemon:$(DIFY_PLUGIN_DAEMON_VERSION) \
	redis:6-alpine \
	ubuntu/squid:latest \
	nginx:latest \
	busybox:latest

up: view
	docker compose up -d

view:
	cat .env | grep -A 1 DIFY_PORT

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
	@echo "dont' forget to nuke the dify database in postgres"

pull:
	docker compose pull

save:
	mkdir -p $(DOCKER_IMAGE_DIR)
	for image in $(DIFY_IMAGES); do \
		file=$$(echo $$image | tr '/:' '__'); \
		docker save $$image | gzip -c -9 > $(DOCKER_IMAGE_DIR)/$$file.tgz; \
	done

tarball: save
	tar -cvf /tmp/dify.tgz -C /tmp/docker dify

load:
	for image in $(DOCKER_IMAGE_DIR)/*.tgz; do \
		gzip -d -c $$image | docker load; \
	done
