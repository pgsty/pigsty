-include .env
export

default: up view

up: view
	docker compose up -d

# make a /data/jupyter dir and change owner to default
dir:
	sudo mkdir -p /data/jupyter; sudo chown -R 1000:100 /data/jupyter

run: dir
	docker run --init --name jupyter --restart always --detach \
		--publish $(JUPYTER_PORT):8888 \
		--volume /data/jupyter:/home/jovyan/work \
		--env JUPYTER_TOKEN=$(JUPYTER_TOKEN) \
		$(JUPYTER_IMAGE)

view:
	@echo "visit http://lab.pigsty  or  http://10.10.10.10:$(JUPYTER_PORT)"

log:
	docker logs -f jupyter

info:
	docker inspect jupyter | jq

stop:
	docker stop jupyter;

clean:
	docker stop jupyter; docker rm -f jupyter

# clean data
purge:
	sudo rm -rf /data/jupyter

pull:
	docker compose pull

rmi:
	docker rmi $(JUPYTER_IMAGE)

save:
	mkdir -p /tmp/docker
	docker save $(JUPYTER_IMAGE) | gzip -9 -c > /tmp/docker/jupyter.tgz

load:
	cat /tmp/docker/jupyter.tgz | gzip -d -c - | docker load

.PHONY: default up dir run view log info stop clean purge pull rmi save load
