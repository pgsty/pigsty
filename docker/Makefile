#==============================================================#
# File      :   Makefile
# Desc      :   Pigsty Docker Image Build & Run
# Ctime     :   2025-01-27
# Mtime     :   2025-01-27
# License   :   Apache-2.0 @ https://pigsty.io/docs/about/license
# Copyright :   2018-2025  Ruohang Feng / Vonng (rh@vonng.com)
#==============================================================#
#
# Quick Start:
#   make up             # Start with docker compose
#   make exec           # Enter container, then run: ./deploy.yml
#
# Or use one-liner:
#   make launch         # up + deploy
#
#==============================================================#


#--------------------------------------------------------------#
# Platform Detection
#--------------------------------------------------------------#
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

ifeq ($(UNAME_S),Darwin)
    OS := macos
else
    OS := linux
endif

ifeq ($(UNAME_M),x86_64)
    ARCH := amd64
else ifeq ($(UNAME_M),aarch64)
    ARCH := arm64
else ifeq ($(UNAME_M),arm64)
    ARCH := arm64
else
    $(error Unsupported architecture: $(UNAME_M))
endif


#--------------------------------------------------------------#
# Configuration Variables
#--------------------------------------------------------------#
VERSION      ?= v4.0.0
REGISTRY     ?= pgsty
NAME         ?= pigsty
DATA         ?= $(PWD)/data

# Port mappings (host:container)
SSH_PORT     ?= 2222
HTTP_PORT    ?= 8080
HTTPS_PORT   ?= 8443
PG_PORT      ?= 5432

# Derived variables
TAG          ?= $(VERSION)
IMAGE        := $(REGISTRY)/pigsty:$(TAG)


#--------------------------------------------------------------#
# Default & Help
#--------------------------------------------------------------#
default: help

help:
	@echo "============================================================"
	@echo "Pigsty Docker Image"
	@echo "============================================================"
	@echo ""
	@echo "Quick Start:"
	@echo "  make up             # Start container with docker compose"
	@echo "  make exec           # Enter container"
	@echo "  make deploy         # Run ./deploy.yml inside container"
	@echo "  make launch         # up + deploy (one-liner)"
	@echo ""
	@echo "Compose Commands:"
	@echo "  make up             # Create and start container"
	@echo "  make down           # Stop and remove container"
	@echo "  make start/stop     # Start/stop container"
	@echo "  make restart        # Restart container"
	@echo "  make pull           # Pull latest image"
	@echo ""
	@echo "Build Commands:"
	@echo "  make build          # Build image locally"
	@echo "  make buildnc        # Build without cache"
	@echo "  make push           # Build and push multi-arch image"
	@echo ""
	@echo "Alternative (docker run):"
	@echo "  make run            # Run with docker run"
	@echo "  make clean          # Stop and remove container"
	@echo "  make purge          # Remove container + delete data"
	@echo ""
	@echo "Container Access:"
	@echo "  make exec           # Bash into container"
	@echo "  make ssh            # SSH into container"
	@echo "  make log/status/ps  # View logs/status/processes"
	@echo ""
	@echo "Current: OS=$(OS) ARCH=$(ARCH) VERSION=$(VERSION)"
	@echo "         IMAGE=$(IMAGE)"
	@echo "         SSH=$(SSH_PORT) HTTP=$(HTTP_PORT) PG=$(PG_PORT)"
	@echo ""


#--------------------------------------------------------------#
# Docker Compose (Recommended)
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
	docker compose exec pigsty ./configure -c docker -g --ip 127.0.0.1

d: deploy
deploy:
	docker compose exec pigsty ./deploy.yml


#--------------------------------------------------------------#
# Container Access
#--------------------------------------------------------------#
e: exec
exec:
	docker exec -it $(NAME) /bin/bash -l

s: ssh
sshi:
	sshpass -p pigsty ssh-copy-id -p $(SSH_PORT) root@localhost

ssh:
	ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		root@localhost -p $(SSH_PORT)

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


#--------------------------------------------------------------#
# Image Build
#--------------------------------------------------------------#
build:
	@echo "Building $(IMAGE) for $(ARCH)..."
	docker build --platform=linux/$(ARCH) -t $(IMAGE) .

buildnc:
	@echo "Building $(IMAGE) without cache for $(ARCH)..."
	docker build --no-cache --platform=linux/$(ARCH) -t $(IMAGE) .

push:
	@echo "Building and pushing $(IMAGE) (multi-arch)..."
	docker buildx build --platform linux/amd64,linux/arm64 \
		-t $(IMAGE) --push .


#--------------------------------------------------------------#
# Container Run (docker run alternative)
#--------------------------------------------------------------#
run:
	@mkdir -p $(DATA)
	docker run -d --privileged \
		--platform=linux/$(ARCH) \
		--name=$(NAME) \
		--hostname=$(NAME) \
		-v $(DATA):/data \
		-p $(SSH_PORT):22 \
		-p $(HTTP_PORT):80 \
		-p $(HTTPS_PORT):443 \
		-p $(PG_PORT):5432 \
		$(IMAGE)
	@echo ""
	@echo "Container '$(NAME)' started with $(IMAGE)"
	@echo ""
	@echo "Next steps:"
	@echo "  make exec       # Enter container"
	@echo "  ./deploy.yml    # Deploy Pigsty"
	@echo ""


#--------------------------------------------------------------#
# Container Lifecycle
#--------------------------------------------------------------#
rm:
	@docker rm $(NAME) 2>/dev/null || true

clean: stop rm

purge: clean
	@echo ""
	@echo "WARNING: This will DELETE all data in ./data"
	@echo ""
	@for i in 2 1; do \
		echo "  Deleting in $$i... (Ctrl+C to cancel)"; \
		sleep 1; \
	done
	rm -rf $(DATA)
	@echo "Data removed."


#--------------------------------------------------------------#
# Image Management
#--------------------------------------------------------------#
save:
	@echo "Saving $(IMAGE) to pigsty-$(TAG)-$(ARCH).tgz..."
	docker save $(IMAGE) | gzip -c > pigsty-$(TAG)-$(ARCH).tgz

load:
	@echo "Loading from pigsty-$(TAG)-$(ARCH).tgz..."
	gzip -d -c pigsty-$(TAG)-$(ARCH).tgz | docker load

rmi:
	docker rmi $(IMAGE) 2>/dev/null || true


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
shell:
	docker run -it --rm --privileged --platform=linux/$(ARCH) $(IMAGE) /bin/bash

test:
	docker run -it --rm --platform=linux/$(ARCH) debian:trixie /bin/bash

all: build run

rebuild: clean build run


#--------------------------------------------------------------#
# Phony Targets
#--------------------------------------------------------------#
.PHONY: default help \
        up down start stop restart pull deploy launch \
        exec ssh log status ps conf pass \
        build buildnc push \
        run rm clean purge \
        save load rmi \
        ip inspect top shell test all rebuild
