default: up view

DOCKER_IMAGE_DIR=/tmp/docker/

up: view
	docker compose up -d

view:
	cat .env | grep -E '^(HINDSIGHT_(API_PUBLISH_PORT|UI_PUBLISH_PORT|DB_NAME|DB_USER|API_LLM_PROVIDER|API_LLM_MODEL|API_VECTOR_EXTENSION|API_TEXT_SEARCH_EXTENSION))='

log:
	docker compose logs -f

info:
	docker compose ps

down: stop
stop:
	docker compose down

clean:
	docker compose rm
	@echo "dont' forget to nuke the hindsight database in postgres if needed"

pull:
	docker compose pull

save:
	mkdir -p $(DOCKER_IMAGE_DIR)
	docker save ghcr.io/vectorize-io/hindsight:latest | gzip -c -9 > $(DOCKER_IMAGE_DIR)/hindsight.tgz

tarball: save
	tar -cvf /tmp/hindsight.tgz -C /tmp/docker hindsight.tgz

load:
	cat $(DOCKER_IMAGE_DIR)/hindsight.tgz | gzip -d -c - | docker load
