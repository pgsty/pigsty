#==============================================================#
# File      :   Makefile
# Desc      :   Pigsty Docker Image Build & Run
# Ctime     :   2026-01-27
# Mtime     :   2026-01-27
# License   :   Apache-2.0 @ https://pigsty.io/docs/about/license
# Copyright :   2018-2026  Ruohang Feng / Vonng (rh@vonng.com)
#==============================================================#
#
# Quick Start:
#   make build          # Build image
#   make run            # Run container
#   make exec           # Enter container, then:
#                       #   ./configure -c docker -i 127.0.0.1
#                       #   ./deploy.yml
#
#==============================================================#


#--------------------------------------------------------------#
# Architecture Detection
#--------------------------------------------------------------#
# Automatically detect host architecture
# Supported: amd64 (x86_64), arm64 (aarch64, Apple Silicon)
#--------------------------------------------------------------#
UNAME_M := $(shell uname -m)
ifeq ($(UNAME_M),x86_64)
    ARCH := amd64
else ifeq ($(UNAME_M),aarch64)
    ARCH := arm64
else ifeq ($(UNAME_M),arm64)
    ARCH := arm64
else
    $(error Unsupported architecture: $(UNAME_M). Only amd64 and arm64 are supported.)
endif


#--------------------------------------------------------------#
# Configuration Variables
#--------------------------------------------------------------#
VERSION      ?= v4.0.0
REGISTRY     ?= pgsty
IMAGE_NAME   ?= pigsty
NAME         ?= pigsty
DATA         ?= $(PWD)/data

# Port mappings (host:container)
SSH_PORT     ?= 2222
HTTP_PORT    ?= 8080
HTTPS_PORT   ?= 8443
PG_PORT      ?= 5432

# Derived variables
IMAGE        := $(IMAGE_NAME):$(VERSION)
IMAGE_LATEST := $(IMAGE_NAME):latest


#--------------------------------------------------------------#
# Default & Help
#--------------------------------------------------------------#
default: help

help:
	@echo "============================================================"
	@echo "Pigsty Docker Image Builder"
	@echo "============================================================"
	@echo ""
	@echo "Compose Commands (Recommended):"
	@echo "  make pull           Pull latest image from Docker Hub"
	@echo "  make up             Create and start container"
	@echo "  make down           Stop and remove container"
	@echo "  make start          Start stopped container"
	@echo "  make stop           Stop running container"
	@echo "  make restart        Restart container"
	@echo "  make config         Run ./configure -c docker -g"
	@echo "  make deploy         Run ./deploy.yml"
	@echo ""
	@echo "Quick Start:"
	@echo "  make launch         # up + config + deploy"
	@echo ""
	@echo "Build Commands:"
	@echo "  make build          Build image locally"
	@echo "  make push           Build & push multi-arch image"
	@echo ""
	@echo "Alternative (docker run):"
	@echo "  make run            Run container with docker run"
	@echo "  make clean          Stop and remove container"
	@echo "  make purge          Remove container AND data"
	@echo ""
	@echo "Container Access:"
	@echo "  make exec           Exec bash into container"
	@echo "  make ssh            SSH into container"
	@echo "  make log            Show container logs"
	@echo "  make status         Show systemd status"
	@echo ""
	@echo "Image Management:"
	@echo "  make save           Export image to tarball"
	@echo "  make load           Import image from tarball"
	@echo "  make rmi            Remove image"
	@echo ""
	@echo "Current Settings:"
	@echo "  ARCH=$(ARCH)  VERSION=$(VERSION)  NAME=$(NAME)"
	@echo "  SSH=$(SSH_PORT)  HTTP=$(HTTP_PORT)  PG=$(PG_PORT)"
	@echo ""
	@echo "Examples:"
	@echo "  make build run exec           # Build, run, enter container"
	@echo "  make clean build run          # Rebuild from scratch"
	@echo "  PG_PORT=15432 make run        # Use different PG port"
	@echo "  DATA=/mnt/data make run       # Custom data directory"
	@echo ""


#--------------------------------------------------------------#
# Docker Compose
#--------------------------------------------------------------#
launch: up config deploy
up:
	docker compose up -d

down:
	docker compose down

start:
	docker compose start

stop:
	docker compose stop

restart:
	docker compose restart

pull:
	docker compose pull

c: config
config:
	docker compose exec pigsty ./configure -c docker -g -i 127.0.0.1

d: deploy
deploy:
	docker compose exec pigsty ./deploy.yml

# directly exec into container
e: exec
exec:
	docker exec -it -w /root/pigsty $(NAME) /bin/bash -l

# copy your ssh key into container for passwordless ssh
s: ssh
sshi:
	sshpass -p pigsty ssh-copy-id -p $(SSH_PORT) root@localhost
ssh:
	ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		root@localhost -p $(SSH_PORT)

#--------------------------------------------------------------#
# Image Build
#--------------------------------------------------------------#
build:
	@echo "Building $(IMAGE) for $(ARCH)..."
	docker build --platform=linux/$(ARCH) \
		-t $(IMAGE) \
		-t $(IMAGE_LATEST) \
		.

# Multi-arch build & push (requires docker buildx)
push:
	@echo "Building & pushing multi-arch $(REGISTRY)/$(IMAGE_NAME):$(VERSION)..."
	docker buildx build --platform linux/amd64,linux/arm64 \
		-t $(REGISTRY)/$(IMAGE_NAME):$(VERSION) \
		-t $(REGISTRY)/$(IMAGE_NAME):latest \
		--push .


#--------------------------------------------------------------#
# Container Run
#--------------------------------------------------------------#
# Runs container with:
#   --privileged: Required for systemd
#   --cgroupns=host: Required for systemd cgroup access
#   -v cgroup: Mount host cgroup for systemd
#   -v data: Persistent data volume
#--------------------------------------------------------------#
run:
	@mkdir -p $(DATA)
	docker run -d --privileged \
		--platform=linux/$(ARCH) \
		--name=$(NAME) \
		--hostname=$(NAME) \
		--cgroupns=host \
		-v /sys/fs/cgroup:/sys/fs/cgroup:rw \
		-v $(DATA):/data \
		-p $(SSH_PORT):22 \
		-p $(HTTP_PORT):80 \
		-p $(HTTPS_PORT):443 \
		-p $(PG_PORT):5432 \
		$(IMAGE)
	@echo ""
	@echo "============================================================"
	@echo "Container '$(NAME)' started"
	@echo "============================================================"
	@echo ""
	@echo "Next steps:"
	@echo "  make exec                               # Enter container"
	@echo "  ./configure -c docker -g -i 127.0.0.1   # Configure"
	@echo "  ./deploy.yml                            # Deploy"
	@echo ""
	@echo "After deployment:"
	@echo "  SSH:   ssh root@localhost -p $(SSH_PORT)  (password: pigsty)"
	@echo "  HTTP:  http://localhost:$(HTTP_PORT)"
	@echo "  PGSQL: psql postgres://dbuser_dba@localhost:$(PG_PORT)/postgres"
	@echo ""


#--------------------------------------------------------------#
# Container Lifecycle
#--------------------------------------------------------------#
rm:
	@docker rm $(NAME) 2>/dev/null || true

clean: stop rm

purge: stop rm
	@echo ""
	@echo "============================================================"
	@echo "  WARNING: This will PERMANENTLY DELETE all data in ./data"
	@echo "============================================================"
	@echo ""
	@echo "  Container: $(NAME)"
	@echo "  Data path: $(DATA)"
	@echo ""
	@echo "  This action is IRREVERSIBLE!"
	@echo ""
	@for i in 5 4 3 2 1; do \
		echo "  Deleting in $$i seconds... (Ctrl+C to cancel)"; \
		sleep 1; \
	done
	@echo ""
	rm -rf $(DATA)
	@echo "  Data directory removed."
	@echo ""


#--------------------------------------------------------------#
# Container Access
#--------------------------------------------------------------#
log:
	docker logs -f $(NAME)

status:
	docker exec -it $(NAME) systemctl status

ps:
	docker exec -it $(NAME) ps aux

conf:
	docker exec $(NAME) cat /root/pigsty/pigsty.yml

pass:
	@docker exec $(NAME) grep password /root/pigsty/pigsty.yml 2>/dev/null || echo "No passwords found"

cat:
	docker exec $(NAME) cat /root/pigsty/pigsty.yml


#--------------------------------------------------------------#
# Image Save/Load (for offline transfer)
#--------------------------------------------------------------#
save:
	@echo "Saving $(IMAGE) to $(IMAGE_NAME)-$(VERSION)-$(ARCH).tgz..."
	docker save $(IMAGE) | gzip -c > $(IMAGE_NAME)-$(VERSION)-$(ARCH).tgz

load:
	@echo "Loading from $(IMAGE_NAME)-$(VERSION)-$(ARCH).tgz..."
	gzip -d -c $(IMAGE_NAME)-$(VERSION)-$(ARCH).tgz | docker load

rmi:
	docker rmi $(IMAGE) $(IMAGE_LATEST) 2>/dev/null || true


#--------------------------------------------------------------#
# Inspection
#--------------------------------------------------------------#
ip:
	@docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(NAME)

inspect:
	docker inspect $(NAME)

top:
	docker top $(NAME)


#--------------------------------------------------------------#
# Utility
#--------------------------------------------------------------#
# Interactive shell without starting systemd
shell:
	docker run -it --rm --privileged \
		--platform=linux/$(ARCH) \
		--cgroupns=host \
		-v /sys/fs/cgroup:/sys/fs/cgroup:rw \
		$(IMAGE) /bin/bash

# Test with plain debian (for debugging)
test:
	docker run -it --rm --platform=linux/$(ARCH) debian:trixie /bin/bash


#--------------------------------------------------------------#
# Batch Operations
#--------------------------------------------------------------#
all: build run

rebuild: clean build run


#--------------------------------------------------------------#
# Phony Targets
#--------------------------------------------------------------#
.PHONY: default help \
        up down start stop restart pull \
        config deploy launch \
        build push \
        run rm clean purge \
        exec ssh log status ps pass conf \
        save load rmi \
        ip inspect top shell test all rebuild
