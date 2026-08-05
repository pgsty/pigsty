default: up view

up:
	docker compose up -d

down:
	docker compose down

view:
	@addr=$$(sed -n 's/^FERRETDB_BIND_ADDR=//p' .env); \
	port=$$(sed -n 's/^FERRETDB_PORT=//p' .env); \
	echo "mongosh 'mongodb://mongod:<password>@$${addr:-127.0.0.1}:$${port:-27017}/'"

health:
	docker inspect --format='{{.State.Health.Status}}' ferretdb

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
	docker image save $$(docker compose config --images) | gzip -9 -c > /tmp/docker/ferretdb.tgz

load:
	gzip -d -c /tmp/docker/ferretdb.tgz | docker image load

.PHONY: default up down view health ping log info start stop restart pull rmi save load
