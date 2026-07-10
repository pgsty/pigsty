default: up view

up: view
	docker compose up -d

run:
	docker run -d --name nocodb \
		-v "/data/nocodb:/usr/app/data/" \
		-p 9003:8080 \
		-e DATABASE_URL="postgres://dbuser_noco:DBUser.Noco@10.10.10.10:5432/noco" \
		-e NC_AUTH_JWT_SECRET="some-secret-password" \
		nocodb/nocodb:latest

view:
	@echo "visit http://noco.pigsty  or  http://10.10.10.10:9003"

log:
	docker logs -f nocodb

info:
	docker inspect nocodb | jq

stop:
	docker stop nocodb;

clean:
	docker stop nocodb; docker rm -f nocodb

pull:
	docker pull nocodb/nocodb:latest

rmi:
	docker rmi nocodb/nocodb:latest

save:
	mkdir -p /tmp/docker
	docker save nocodb/nocodb:latest | gzip -9 -c > /tmp/docker/nocodb.tgz

load:
	cat /tmp/docker/nocodb.tgz | gzip -d -c - | docker load

.PHONY: default up run view log info stop clean pull rmi save load
