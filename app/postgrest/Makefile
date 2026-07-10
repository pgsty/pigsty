-include .env
export

default: up view

up: view
	docker compose up -d

run:
	docker run --init --name postgrest --restart always --detach \
		--publish $(POSTGREST_SERVER_PORT):$(POSTGREST_SERVER_PORT) \
		--env PGRST_DB_URI=$(POSTGREST_DB_URI) \
		--env PGRST_DB_SCHEMA=$(POSTGREST_DB_SCHEMA) \
		--env PGRST_DB_ANON_ROLE=$(POSTGREST_DB_ANON_ROLE) \
		--env PGRST_SERVER_PORT=$(POSTGREST_SERVER_PORT) \
		--env PGRST_JWT_SECRET=$(POSTGREST_JWT_SECRET) \
		postgrest/postgrest

ui:
	docker run --init --name swagger -d -p 8883:8080 \
		-e API_URL=http://10.10.10.10:$(POSTGREST_SERVER_PORT) swaggerapi/swagger-ui

view:
	@echo "visit http://10.10.10.10:$(POSTGREST_SERVER_PORT) for API Spec"

log:
	docker logs -f postgrest

info:
	docker inspect postgrest | jq

stop:
	docker stop postgrest;

clean:
	docker stop postgrest; docker rm -f postgrest

rmui:
	docker rm -f swagger

pull:
	docker pull postgrest/postgrest

rmi:
	docker rmi postgrest/postgrest

save:
	mkdir -p /tmp/docker
	docker save postgrest/postgrest | gzip -9 -c > /tmp/docker/postgrest.tgz

load:
	cat /tmp/docker/postgrest.tgz | gzip -d -c - | docker load

.PHONY: default up run ui rmui view log info stop clean pull rmi save load
