default: up view

up:
	docker compose up -d
start: up

view:
	@echo "visit http://isf.pigsty (or http://10.10.10.10:7130) for InsForge dashboard"

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
	docker save postgrest/postgrest:v12.2.12          | gzip -c -9 > /tmp/docker/insforge/postgrest.tgz
	docker save ghcr.io/insforge/insforge-oss:v2.0.1  | gzip -c -9 > /tmp/docker/insforge/insforge.tgz
	docker save ghcr.io/insforge/deno-runtime:latest   | gzip -c -9 > /tmp/docker/insforge/deno.tgz

tarball: save
	tar -cvf /tmp/insforge.tgz -C /tmp/docker insforge

load:
	cat /tmp/docker/insforge/postgrest.tgz | gzip -d -c - | docker load
	cat /tmp/docker/insforge/insforge.tgz  | gzip -d -c - | docker load
	cat /tmp/docker/insforge/deno.tgz      | gzip -d -c - | docker load

.PHONY: default up down start stop view log info restart clean edit pull save load tarball
