SHELL := /bin/bash -e -o pipefail

default: up view

DOCKER_IMAGE_DIR=/tmp/docker/dify

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
	@echo "Application files, signing keys and PostgreSQL data are preserved."

pull:
	docker compose pull

save:
	mkdir -p "$(DOCKER_IMAGE_DIR)"
	@images="$$(docker compose config --images | sort -u)"; test -n "$$images"; \
	for image in $$images; do \
		file=$$(printf '%s' "$$image" | tr '/:' '__'); \
		archive_path="$(DOCKER_IMAGE_DIR)/$$file.tgz"; \
		archive_tmp=$$(mktemp "$$archive_path.tmp.XXXXXX"); \
		trap 'rm -f -- "$$archive_tmp"' EXIT; \
		docker save "$$image" | gzip -c -9 > "$$archive_tmp"; \
		mv -f -- "$$archive_tmp" "$$archive_path"; \
		trap - EXIT; \
	done

tarball: save
	tar -cvf /tmp/dify.tgz -C /tmp/docker dify

load:
	for image in "$(DOCKER_IMAGE_DIR)"/*.tgz; do \
		gzip -d -c "$$image" | docker load; \
	done
