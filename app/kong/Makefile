default: up view

bootstrap:
	docker compose --profile bootstrap run --rm kong-migration

up: view
	docker compose up -d kong

view:
	@echo "admin url: http://10.10.10.10:8001"

ui:
	docker run --init --name swagger -d -p 8882:8080 -e API_URL=http://10.10.10.10:8001 swaggerapi/swagger-ui

rmui:
	docker rm -f swagger

log:
	docker logs -f kong

info:
	docker inspect kong | jq

stop:
	docker stop kong;

clean:
	docker stop kong; docker rm -f kong


pull:
	docker pull kong

rmi:
	docker rmi kong

save:
	mkdir -p /tmp/docker
	docker save kong | gzip -9 -c > /tmp/docker/kong.tgz

load:
	cat /tmp/docker/kong.tgz | gzip -d -c - | docker load

.PHONY: default bootstrap up view ui rmui log info stop clean pull rmi save load
