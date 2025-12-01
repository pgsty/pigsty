default: init up view

# init odoo dir & database schema
init:
	docker compose --profile init up odoo-init
dir:
	mkdir -p /data/odoo /data/odoo/webdata /data/odoo/addons
	chown 100:101 /data/odoo /data/odoo/webdata /data/odoo/addons
view:
	@echo "visit http://odoo.pigsty  or  http://10.10.10.10:8069"

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
logs:
	docker compose logs -f
port:
	docker compose port
conf:
	docker compose config
info:
	docker inspect odoo | jq


save:
	mkdir -p /tmp/docker
	docker save odoo/odoo:19.0 | gzip -9 -c > /tmp/docker/odoo.tgz
load:
	cat /tmp/docker/odoo.tgz | gzip -d -c - | docker load

.PHONY: default init view up down stop start restart pause resume pull rm logs port conf info save load