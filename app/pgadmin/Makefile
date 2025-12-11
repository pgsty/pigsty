default: up view

up:
	docker compose up -d
down:
	docker compose down
run:
	docker run --init --name pgadmin --restart always --detach --publish 8885:80 \
	-e PGADMIN_DEFAULT_EMAIL=admin@pigsty.cc -e PGADMIN_DEFAULT_PASSWORD=pigsty \
	dpage/pgadmin4
view:
	@echo "visit http://adm.pigsty  or  http://10.10.10.10:8885"
	@echo "cred: admin@pigsty.cc  /  pigsty"
log:
	docker logs -f pgadmin
info:
	docker inspect pgadmin | jq
clean:
	docker stop pgadmin; docker rm -f pgadmin
edit:
	vi .env
pull:
	docker compose pull
rmi:
	docker rmi dpage/pgadmin4
start:
	docker compose start
stop:
	docker compose stop
restart:
	docker compose restart
exec:
	docker exec -u 0 -it pgadmin /bin/bash

reload: list pass
conf: list pass
pass:
	docker exec pgadmin cp /pgadmin4/pgpass /var/lib/pgadmin/storage/admin_pigsty.cc/pgpass;
list:
	docker exec pgadmin /venv/bin/python3 /pgadmin4/setup.py load-servers --replace --user admin@pigsty.cc /pgadmin4/servers.json

# load pigsty server list manually
servers:
	docker cp /infra/pgadmin/servers.json pgadmin:/tmp/servers.json;
	docker exec -u 0 -it pgadmin chown pgadmin /tmp/servers.json;
	docker exec -it pgadmin /venv/bin/python3 /pgadmin4/setup.py load-servers --replace --user admin@pigsty.cc /tmp/servers.json
# load pgpass manually
pgpass:
	docker cp /infra/pgadmin/pgpass pgadmin:/var/lib/pgadmin/storage/admin_pigsty.cc/pgpass;
	docker exec -u 0 -it pgadmin chown pgadmin /var/lib/pgadmin/storage/admin_pigsty.cc/pgpass;


dump: save
save:
	mkdir -p /tmp/docker
	docker save dpage/pgadmin4 | gzip -9 -c > /tmp/docker/pgadmin4.tgz
load:
	cat /tmp/docker/pgadmin4.tgz | gzip -d -c - | docker load

.PHONY: default up down run view log info clean edit pull start stop restart exec reload conf list pass servers pgpass rmi dump save load