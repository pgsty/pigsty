SHELL := /bin/bash -e -o pipefail

default: up view

up:
	docker compose up -d
start: up

view:
	@docker compose config --format json | jq -r '.services.insforge.ports[] | select(.target == 7130) | "InsForge dashboard published on port \(.published)"'

log:
	docker compose logs -f

info:
	docker compose ps

down: stop
stop:
	docker compose down

restart:
	docker compose restart

clean:
	docker compose rm

edit:
	vi .env

pull:
	docker compose pull

save:
	mkdir -p /tmp/docker/insforge
	@config="$$(docker compose config --format json)"; \
	for service in postgrest insforge deno; do \
		image="$$(printf '%s' "$$config" | jq -er --arg service "$$service" '.services[$$service].image')"; \
		archive_path="/tmp/docker/insforge/$$service.tgz"; \
		archive_tmp=$$(mktemp "$$archive_path.tmp.XXXXXX"); \
		trap 'rm -f -- "$$archive_tmp"' EXIT; \
		docker save "$$image" | gzip -c -9 > "$$archive_tmp"; \
		mv -f -- "$$archive_tmp" "$$archive_path"; \
		trap - EXIT; \
	done

tarball: save
	tar -cvf /tmp/insforge.tgz -C /tmp/docker insforge

load:
	cat /tmp/docker/insforge/postgrest.tgz | gzip -d -c - | docker load
	cat /tmp/docker/insforge/insforge.tgz  | gzip -d -c - | docker load
	cat /tmp/docker/insforge/deno.tgz      | gzip -d -c - | docker load

.PHONY: default up down start stop view log info restart clean edit pull save load tarball
