SHELL := /bin/bash -e -o pipefail

default: up view

up: dir view
	docker compose up -d

# make a /data/jupyter dir and change owner to default
dir:
	sudo mkdir -p /data/jupyter; sudo chown -R 1000:100 /data/jupyter

run: up

view:
	@docker compose config --format json | jq -r '.services.jupyter.ports[] | select(.target == 8888) | "visit http://lab.pigsty or http://10.10.10.10:\(.published)"'

log:
	docker logs -f jupyter

info:
	docker inspect jupyter | jq

stop:
	docker stop jupyter;

clean:
	docker stop jupyter; docker rm -f jupyter

# clean data
purge:
	sudo rm -rf /data/jupyter

pull:
	docker compose pull

rmi:
	docker rmi $$(docker compose config --images)

save:
	mkdir -p /tmp/docker
	@images="$$(docker compose config --images)"; test -n "$$images"; \
	archive_path="/tmp/docker/jupyter.tgz"; \
	archive_tmp=$$(mktemp "$$archive_path.tmp.XXXXXX"); \
	trap 'rm -f -- "$$archive_tmp"' EXIT; \
	docker save $$images | gzip -9 -c > "$$archive_tmp"; \
	mv -f -- "$$archive_tmp" "$$archive_path"; \
	trap - EXIT

load:
	cat /tmp/docker/jupyter.tgz | gzip -d -c - | docker load

.PHONY: default up dir run view log info stop clean purge pull rmi save load
