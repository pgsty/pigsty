###############################################################
# Pigsty Maybe App (Personal Finance Management)
###############################################################

DOCKER_COMPOSE := docker compose --env-file .env -f docker-compose.yml

default: up view
start: up

up:
	$(DOCKER_COMPOSE) up -d

run:
	$(DOCKER_COMPOSE) up

view:
	@echo "visit http://maybe.pigsty or http://10.10.10.10:$$(grep -E '^MAYBE_PORT=' .env | cut -d= -f2)"
	@grep -E '^(MAYBE_IMAGE|MAYBE_VERSION|MAYBE_PORT|MAYBE_DATA|APP_DOMAIN|DB_HOST|DB_PORT|POSTGRES_USER|POSTGRES_DB)=' .env

pull:
	$(DOCKER_COMPOSE) pull

config:
	$(DOCKER_COMPOSE) config

restart:
	$(DOCKER_COMPOSE) restart

stop: down
down:
	$(DOCKER_COMPOSE) down

clean:
	$(DOCKER_COMPOSE) rm -f
	@echo "application containers removed; Maybe data remains under MAYBE_DATA and PostgreSQL"

log logs:
	$(DOCKER_COMPOSE) logs -f

status ps:
	$(DOCKER_COMPOSE) ps

health:
	curl -fsS "http://127.0.0.1:$$(grep -E '^MAYBE_PORT=' .env | cut -d= -f2)/up"

migrate:
	docker exec maybe-web ./bin/rails db:prepare

console:
	docker exec -it maybe-web ./bin/rails console

exec:
	docker exec -it maybe-web bash

.PHONY: default start up run view pull config restart stop down clean log logs status ps health migrate console exec
