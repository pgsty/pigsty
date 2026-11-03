SHELL := /bin/bash -e -o pipefail

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

health:
	docker compose exec -T hindsight sh -c 'curl -fsS "http://127.0.0.1:$${HINDSIGHT_API_PORT:-8888}/health/ready"'
	docker compose exec -T hindsight curl -fsS -o /dev/null 'http://127.0.0.1:9999/api/banks?limit=1'

down: stop
stop:
	docker compose down

clean:
	docker compose rm
	@echo "application containers removed; PostgreSQL data and the hindsight-cache volume are preserved"

pull:
	docker compose pull

save:
	mkdir -p $(DOCKER_IMAGE_DIR)
	@images="$$(docker compose config --images)"; test -n "$$images"; \
	archive_path="$(DOCKER_IMAGE_DIR)/hindsight.tgz"; \
	archive_tmp=$$(mktemp "$$archive_path.tmp.XXXXXX"); \
	trap 'rm -f -- "$$archive_tmp"' EXIT; \
	docker save $$images | gzip -c -9 > "$$archive_tmp"; \
	mv -f -- "$$archive_tmp" "$$archive_path"; \
	trap - EXIT

tarball: save
	tar -cvf /tmp/hindsight.tgz -C /tmp/docker hindsight.tgz

load:
	cat $(DOCKER_IMAGE_DIR)/hindsight.tgz | gzip -d -c - | docker load

.PHONY: default up view log info health down stop clean pull save tarball load
