default: up view

view:
	@echo "visit http://10.10.10.10:8002"

# administration
up:
	docker compose up -d
down:
	docker compose down
stop:
	docker compose stop
start:
	docker compose start
restart:
	docker compose restart
pause:
	docker compose pause
resume:
	docker compose unpause
pull:
	docker compose pull
rm:
	docker compose rm
log:
	docker compose logs
logs:
	docker compose logs -f
port:
	docker compose port
conf:
	docker compose config
info:
	docker inspect electric | jq
save:
	mkdir -p /tmp/docker
	docker save electric/electric | gzip -9 -c > /tmp/docker/electric.tgz
load:
	cat /tmp/docker/electric.tgz | gzip -d -c - | docker load

.PHONY: default view up down stop start restart pause resume pull rm log logs port conf info save load
