default: up view

up: view
	docker compose up -d

view:
	@echo "visit http://wiki.pigsty  or  http://10.10.10.10:9002"

log:
	docker logs -f wiki

info:
	docker inspect wiki | jq

stop:
	docker stop wiki;

clean:
	docker stop wiki; docker rm -f wiki

pull:
	docker compose pull

rmi:
	docker rmi requarks/wiki

save:
	mkdir -p /tmp/docker
	docker save requarks/wiki | gzip -9 -c > /tmp/docker/wiki.tgz

load:
	cat /tmp/docker/wiki.tgz | gzip -d -c - | docker load

.PHONY: default up view log info stop clean pull rmi save load
