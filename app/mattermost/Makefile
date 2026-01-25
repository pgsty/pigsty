default: up

up: mkdir
	docker compose up -d

mkdir:
	mkdir -p volumes/{config,data,logs,plugins,client/plugins,bleve-indexes}
	chown -R 2000:2000 volumes

view:
	@echo "visit http://mm.pigsty  or  http://10.10.10.10:8065"

log:
	docker compose logs -f

info:
	docker inspect mattermost | jq

stop:
	docker stop mattermost;

clean:
	docker stop mattermost; docker rm -f mattermost

edit:
	vi .env

restart:
	docker compose restart

pull:
	docker compose pull

rmi:
	docker rmi mattermost/mattermost-team-edition

save:
	mkdir -p /tmp/docker
	docker save mattermost/mattermost-team-edition | gzip -9 -c > /tmp/docker/mattermost.tgz

load:
	cat /tmp/docker/mattermost.tgz | gzip -d -c - | docker load

.PHONY: default up mkdir run view log info stop clean edit pull rmi save load