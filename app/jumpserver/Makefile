###############################################################
# Pigsty JumpServer App
###############################################################

DOCKER_COMPOSE := docker compose --env-file .env -f docker-compose.yml

default: up view
start: up

up:
	$(DOCKER_COMPOSE) up -d

run:
	$(DOCKER_COMPOSE) up

view:
	@echo "visit http://jump.pigsty or http://10.10.10.10:$$(grep -E '^HTTP_PORT=' .env | cut -d= -f2)"
	@grep -E '^(JUMPSERVER_VERSION|HTTP_PORT|SSH_PORT|DB_HOST|DB_PORT|DB_USER|DB_NAME|REDIS_HOST|DOCKER_SUBNET)=' .env

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
	@echo "application containers removed; JumpServer data remains under JUMPSERVER_DATA and PostgreSQL"

log logs:
	$(DOCKER_COMPOSE) logs -f

status ps:
	$(DOCKER_COMPOSE) ps

health:
	curl -fsS "http://127.0.0.1:$$(grep -E '^HTTP_PORT=' .env | cut -d= -f2)/api/health/"

migrate upgrade-db:
	$(DOCKER_COMPOSE) exec core bash -c './jms upgrade_db'

exec:
	$(DOCKER_COMPOSE) exec core bash

.PHONY: default start up run view pull config restart stop down clean log logs status ps health migrate upgrade-db exec
