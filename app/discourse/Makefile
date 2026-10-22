SHELL := /bin/bash -e -o pipefail
MANAGE := python3 manage.py
COMPOSE := docker compose --env-file .env -f docker-compose.yml

default: up view

# The first up builds with the official classic Launcher before using Compose.
up:
	$(MANAGE) up
build init:
	$(MANAGE) build
rebuild upgrade:
	$(MANAGE) rebuild
config conf:
	$(MANAGE) config
view:
	$(MANAGE) view

start:
	$(MANAGE) start
stop:
	$(COMPOSE) stop
down clean:
	$(COMPOSE) down
	@echo "container removed; /data/app/discourse and PostgreSQL data preserved"
restart:
	$(COMPOSE) restart
log logs:
	$(COMPOSE) logs -f
info ps:
	$(COMPOSE) ps
health:
	$(COMPOSE) exec -T discourse sh -c 'curl -fsS --unix-socket /shared/nginx.http.sock -H "Host: $$DISCOURSE_HOSTNAME" http://localhost/srv/status'
exec:
	$(COMPOSE) exec discourse bash

# Image archives stay outside the repository and contain private build config.
save:
	$(MANAGE) save
load:
	gzip -dc /tmp/docker/discourse.tgz | docker load

.PHONY: default up build init rebuild upgrade config conf view start stop down clean restart log logs info ps health exec save load
