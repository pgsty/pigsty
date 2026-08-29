SHELL := /bin/bash -e -o pipefail

default: up view

up:
	docker compose up -d

down:
	docker compose down

view:
	@docker compose config --format json | python3 -c 'import json,sys; p=json.load(sys.stdin)["services"]["ferretdb"]["ports"][0]; h=p.get("host_ip") or "127.0.0.1"; h="["+h+"]" if ":" in h else h; print("mongosh " + repr("mongodb://mongod:<password>@"+h+":"+str(p["published"])+"/"))'

health:
	@status=$$(docker inspect --format='{{.State.Health.Status}}' ferretdb); printf '%s\n' "$$status"; test "$$status" = healthy

ping:
	docker exec ferretdb /ferretdb ping

log:
	docker logs -f ferretdb

info:
	docker inspect ferretdb | jq

start:
	docker compose start

stop:
	docker compose stop

restart:
	docker compose restart

pull:
	docker compose pull

rmi:
	docker image rm $$(docker compose config --images)

save:
	mkdir -p /tmp/docker
	@images="$$(docker compose config --images)"; test -n "$$images"; \
	archive_path="/tmp/docker/ferretdb.tgz"; \
	archive_tmp=$$(mktemp "$$archive_path.tmp.XXXXXX"); \
	trap 'rm -f -- "$$archive_tmp"' EXIT; \
	docker image save $$images | gzip -9 -c > "$$archive_tmp"; \
	mv -f -- "$$archive_tmp" "$$archive_path"; \
	trap - EXIT

load:
	gzip -d -c /tmp/docker/ferretdb.tgz | docker image load

.PHONY: default up down view health ping log info start stop restart pull rmi save load
