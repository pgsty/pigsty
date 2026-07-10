-include .env

default: up

up:
	docker compose up -d

run:
	docker run --init --name pg_exporter -p $(PG_EXPORTER_PORT):9630 \
		-e PG_EXPORTER_URL=$(PG_EXPORTER_URL) pgsty/pg_exporter

view:
	curl http://localhost:$(PG_EXPORTER_PORT)/metrics

log:
	docker logs -f pg_exporter

info:
	docker inspect pg_exporter | jq

stop:
	docker stop pg_exporter;

clean:
	docker stop pg_exporter; docker rm -f pg_exporter

pull:
	docker pull pgsty/pg_exporter

rmi:
	docker rmi pgsty/pg_exporter

save:
	mkdir -p /tmp/docker
	docker save pgsty/pg_exporter | gzip -9 -c > /tmp/docker/pg_exporter.tgz

load:
	cat /tmp/docker/pg_exporter.tgz | gzip -d -c - | docker load

.PHONY: default up run view log info stop clean pull rmi save load
