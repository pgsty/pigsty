default: up view

up: view
	docker compose up -d

run:
	docker run -d --name metabase \
		  -p 9004:3000 \
          -e "MB_DB_TYPE=postgres" \
          -e "MB_DB_DBNAME=meta" \
          -e "MB_DB_PORT=5432" \
          -e "MB_DB_USER=dbuser_meta" \
          -e "MB_DB_PASS=DBUser.Meta" \
          -e "MB_DB_HOST=10.10.10.10" \
          metabase/metabase

view:
	@echo "visit http://mtbs.pigsty  or  http://10.10.10.10:9004"

log:
	docker logs -f metabase

info:
	docker inspect metabase | jq

stop:
	docker stop metabase;

clean:
	docker stop metabase; docker rm -f metabase

pull:
	docker pull metabase/metabase:latest

rmi:
	docker rmi metabase/metabase:latest

save:
	mkdir -p /tmp/docker
	docker save metabase/metabase:latest | gzip -9 -c > /tmp/docker/metabase.tgz

load:
	cat /tmp/docker/metabase.tgz | gzip -d -c - | docker load

.PHONY: default up run view log info stop clean pull rmi save load
