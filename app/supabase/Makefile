default: up view

IMG_DIR=/tmp/docker/supabase

up:
	docker compose up -d
start: up

stop: down
down:
	docker compose down

view:
	@echo "visit http://supa.pigsty for supabase studio"

log:
	docker compose logs -f

info:
	docker inspect supabase-studio | jq

restart:
	docker compose restart

clean:
	docker compose rm

edit:
	vi .env

pull:
	docker compose pull

dump: save
save:
	bin/dump

# copy to target machine: scp -r /tmp/docker xxx:/tmp/docker
tz: tarball
tarball: save
	tar -cvf /tmp/supabase.tgz -C /tmp/docker supabase

copy:
	ssh 10.10.10.10 'mkdir -p /tmp/docker/supabase'
	rsync -avz /tmp/docker/supabase/ 10.10.10.10:/tmp/docker/supabase/

load:
	bin/load

.PHONY: default up down start stop view log info restart clean edit pull dump save load tz tarball