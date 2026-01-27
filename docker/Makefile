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
#   make up             # Start with docker compose (recommended)
#   make exec           # Enter container, then:
#                       #   ./configure -c docker --ip 127.0.0.1
#                       #   ./deploy.yml
#
# Or use one-liner:
#   make launch         # up + config + deploy
#
#==============================================================#


#--------------------------------------------------------------#
# Platform Detection
#--------------------------------------------------------------#
# Detect OS: Darwin (macOS) or Linux
# Detect Architecture: amd64 or arm64
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
# Image naming: $(REGISTRY)/<stage>:$(TAG)
# Examples:
#   $(REGISTRY)/linux:v4.0.0    $(REGISTRY)/pigsty:v4.0.0
#   $(REGISTRY)/linux:latest    $(REGISTRY)/pigsty:latest
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
RUN_IMAGE    ?= $(IMAGE)

# Multi-stage image names (5 stages)
STAGES       := linux admin infra pgsql pigsty


#--------------------------------------------------------------#
# Default & Help
#--------------------------------------------------------------#
default: help

help:
	@echo "============================================================"
	@echo "Pigsty Docker Image Builder"
	@echo "============================================================"
	@echo ""
	@echo "Quick Start:"
	@echo "  make launch         # up + config + deploy (one-liner)"
	@echo "  make up             # Start container with docker compose"
	@echo "  make exec           # Enter container"
	@echo ""
	@echo "Compose Commands:"
	@echo "  make up             # Create and start container"
	@echo "  make down           # Stop and remove container"
	@echo "  make start/stop     # Start/stop container"
	@echo "  make restart        # Restart container"
	@echo "  make pull           # Pull latest image"
	@echo "  make config         # Run ./configure"
	@echo "  make deploy         # Run ./deploy.yml"
	@echo ""
	@echo "Build Commands:"
	@echo "  make linux          # Build $(REGISTRY)/linux  (base)"
	@echo "  make admin          # Build $(REGISTRY)/admin  (+ ansible + packages)"
	@echo "  make infra          # Build $(REGISTRY)/infra  (+ monitoring)"
	@echo "  make pgsql          # Build $(REGISTRY)/pgsql  (+ postgresql)"
	@echo "  make pigsty         # Build $(REGISTRY)/pigsty (+ extensions)"
	@echo "  make images         # Build all 5 images"
	@echo ""
	@echo "Push Commands:"
	@echo "  make <stage>-push   # Push specific stage (multi-arch)"
	@echo "  make images-push    # Push all images"
	@echo "  make rmi-all        # Remove all built images"
	@echo ""
	@echo "Alternative (docker run):"
	@echo "  make run            # Run with docker run"
	@echo "  make clean          # Stop and remove"
	@echo "  make purge          # Remove + delete data"
	@echo ""
	@echo "Container Access:"
	@echo "  make exec           # Bash into container"
	@echo "  make ssh            # SSH into container"
	@echo "  make log/status/ps  # View logs/status/processes"
	@echo ""
	@echo "Current: OS=$(OS) ARCH=$(ARCH) VERSION=$(VERSION)"
	@echo "         TAG=$(TAG) SSH=$(SSH_PORT) HTTP=$(HTTP_PORT) PG=$(PG_PORT)"
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
	docker exec -it -w /root/pigsty $(NAME) /bin/bash -l

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
# Image Build (Multi-stage)
#--------------------------------------------------------------#
# Build specific stage: make <stage>
# Inheritance: linux -> admin -> infra -> pgsql -> pigsty
#--------------------------------------------------------------#
linux:
	@echo "Building $(REGISTRY)/linux:$(TAG) for $(ARCH)..."
	docker build --platform=linux/$(ARCH) --target linux \
		-t $(REGISTRY)/linux:$(TAG) .

admin:
	@echo "Building $(REGISTRY)/admin:$(TAG) for $(ARCH)..."
	docker build --platform=linux/$(ARCH) --target admin \
		-t $(REGISTRY)/admin:$(TAG) .

infra:
	@echo "Building $(REGISTRY)/infra:$(TAG) for $(ARCH)..."
	docker build --platform=linux/$(ARCH) --target infra \
		-t $(REGISTRY)/infra:$(TAG) .

pgsql:
	@echo "Building $(REGISTRY)/pgsql:$(TAG) for $(ARCH)..."
	docker build --platform=linux/$(ARCH) --target pgsql \
		-t $(REGISTRY)/pgsql:$(TAG) .

pigsty:
	@echo "Building $(REGISTRY)/pigsty:$(TAG) for $(ARCH)..."
	docker build --platform=linux/$(ARCH) --target pigsty \
		-t $(REGISTRY)/pigsty:$(TAG) .

images:
	@echo "Building all images for $(ARCH)..."
	@for stage in $(STAGES); do \
		echo "Building $(REGISTRY)/$$stage:$(TAG)..."; \
		docker build --platform=linux/$(ARCH) --target $$stage \
			-t $(REGISTRY)/$$stage:$(TAG) . || exit 1; \
	done

build: images


#--------------------------------------------------------------#
# Image Push (Multi-arch)
#--------------------------------------------------------------#
linux-push:
	docker buildx build --platform linux/amd64,linux/arm64 --target linux \
		-t $(REGISTRY)/linux:$(TAG) --push .

admin-push:
	docker buildx build --platform linux/amd64,linux/arm64 --target admin \
		-t $(REGISTRY)/admin:$(TAG) --push .

infra-push:
	docker buildx build --platform linux/amd64,linux/arm64 --target infra \
		-t $(REGISTRY)/infra:$(TAG) --push .

pgsql-push:
	docker buildx build --platform linux/amd64,linux/arm64 --target pgsql \
		-t $(REGISTRY)/pgsql:$(TAG) --push .

pigsty-push:
	docker buildx build --platform linux/amd64,linux/arm64 --target pigsty \
		-t $(REGISTRY)/pigsty:$(TAG) --push .

images-push:
	@for stage in $(STAGES); do \
		echo "Pushing $(REGISTRY)/$$stage:$(TAG)..."; \
		docker buildx build --platform linux/amd64,linux/arm64 --target $$stage \
			-t $(REGISTRY)/$$stage:$(TAG) --push . || exit 1; \
	done

push: images-push


#--------------------------------------------------------------#
# Container Run (docker run alternative)
#--------------------------------------------------------------#
# Works on both macOS (Docker Desktop) and Linux
# --privileged is required for systemd
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
		$(RUN_IMAGE)
	@echo ""
	@echo "Container '$(NAME)' started with $(RUN_IMAGE)"
	@echo ""
	@echo "Next steps:"
	@echo "  make exec                               # Enter container"
	@echo "  ./configure -c docker -g --ip 127.0.0.1 # Configure"
	@echo "  ./deploy.yml                            # Deploy"
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

rmi-all:
	@echo "Removing all pigsty images ($(TAG))..."
	@for stage in $(STAGES); do \
		echo "  Removing $(REGISTRY)/$$stage:$(TAG)..."; \
		docker rmi $(REGISTRY)/$$stage:$(TAG) 2>/dev/null || true; \
	done


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
	docker run -it --rm --privileged --platform=linux/$(ARCH) $(RUN_IMAGE) /bin/bash

test:
	docker run -it --rm --platform=linux/$(ARCH) debian:trixie /bin/bash

all: build run

rebuild: clean build run


#--------------------------------------------------------------#
# Phony Targets
#--------------------------------------------------------------#
.PHONY: default help \
        up down start stop restart pull config deploy launch \
        exec ssh log status ps conf pass \
        linux admin infra pgsql pigsty build images \
        linux-push admin-push infra-push pgsql-push pigsty-push push images-push \
        run rm clean purge \
        save load rmi rmi-all \
        ip inspect top shell test all rebuild
