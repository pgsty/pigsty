default: up view

up: data view
	docker compose up -d

data:
	sudo mkdir -p /data/minio

run: data
	docker run --name minio -p 9000:9000 -p 9001:9001 -v /data/minio:/data \
		-e "MINIO_ROOT_USER=minioadmin" -e "MINIO_ROOT_PASSWORD=S3User.MinIO" \
		pgsty/minio server /data --console-address ":9001"

view:
	@echo "API: http://10.10.10.10:9000; console: http://10.10.10.10:9001"
	@echo "default credentials: minioadmin / S3User.MinIO"

log:
	docker logs -f minio

info:
	docker inspect minio | jq

stop:
	docker stop minio;

clean:
	docker stop minio; docker rm -f minio

pull:
	docker pull pgsty/minio

rmi:
	docker rmi pgsty/minio

save:
	mkdir -p /tmp/docker
	docker save pgsty/minio | gzip -9 -c > /tmp/docker/minio.tgz

load:
	cat /tmp/docker/minio.tgz | gzip -d -c - | docker load

.PHONY: default up data run view log info stop clean pull rmi save load
