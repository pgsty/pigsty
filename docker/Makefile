#==============================================================#
# File      :   Makefile
# Desc      :   Pigsty Docker Image Build & Run
# Ctime     :   2026-01-27
# Mtime     :   2026-01-27
# License   :   Apache-2.0 @ https://pigsty.io/docs/about/license
# Copyright :   2018-2026  Ruohang Feng / Vonng (rh@vonng.com)
#==============================================================#
#
# Two images available:
#
#   pigsty (base):  Pigsty initialized, run configure & deploy yourself
#   pigsty-full:    Pigsty fully deployed, ready to use immediately
#
# Quick Start:
#   make build          # Build base image
#   make run            # Run container
#   make exec           # Enter container, then:
#                       #   ./configure -c docker -i 127.0.0.1
#                       #   ./deploy.yml
#
# Or use full image:
#   make build-full     # Build full image (takes longer)
#   make run-full       # Run fully deployed container
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
IMAGE_BASE   ?= pigsty
IMAGE_FULL   ?= pigsty-full
NAME         ?= pigsty
DATA         ?= $(PWD)/data

# Port mappings (host:container)
SSH_PORT     ?= 2222
HTTP_PORT    ?= 8080
HTTPS_PORT   ?= 8443
PG_PORT      ?= 5432

# Derived variables
IMAGE        := $(IMAGE_BASE):$(VERSION)
IMAGE_LATEST := $(IMAGE_BASE):latest


#--------------------------------------------------------------#
# Default & Help
#--------------------------------------------------------------#
default: help

help:
	@echo "============================================================"
	@echo "Pigsty Docker Image Builder"
	@echo "============================================================"
	@echo ""
	@echo "Two images available:"
	@echo "  pigsty (base)  : Initialized, ready for configure & deploy"
	@echo "  pigsty-full    : Fully deployed, ready to use immediately"
	@echo ""
	@echo "Build Commands:"
	@echo "  make build          Build base image (pigsty)"
	@echo "  make build-full     Build full image (pigsty-full)"
	@echo "  make build-multiarch      Build & push multi-arch base"
	@echo "  make build-multiarch-full Build & push multi-arch full"
	@echo ""
	@echo "Run Commands:"
	@echo "  make run            Run base image container"
	@echo "  make run-full       Run full image container"
	@echo "  make start          Start stopped container"
	@echo "  make stop           Stop running container"
	@echo "  make restart        Restart container"
	@echo "  make clean          Stop and remove container (keep data)"
	@echo "  make purge          Stop, remove container AND delete data"
	@echo ""
	@echo "Access Commands:"
	@echo "  make exec           Exec bash into container"
	@echo "  make ssh            SSH into container"
	@echo "  make log            Show container logs"
	@echo "  make status         Show systemd status"
	@echo "  make pass           Show passwords from config"
	@echo "  make conf           Show pigsty.yml config"
	@echo ""
	@echo "Image Management:"
	@echo "  make pull           Pull base image from Docker Hub"
	@echo "  make push           Push base image to Docker Hub"
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
# Image Build
#--------------------------------------------------------------#
# build:      Build base image (Dockerfile target: base)
# build-full: Build full image (Dockerfile target: full)
#--------------------------------------------------------------#
build:
	@echo "Building $(IMAGE) for $(ARCH)..."
	docker build --platform=linux/$(ARCH) \
		--target base \
		-t $(IMAGE) \
		-t $(IMAGE_LATEST) \
		.

build-full:
	@echo "Building $(IMAGE_FULL):$(VERSION) for $(ARCH)..."
	docker build --platform=linux/$(ARCH) \
		--target full \
		-t $(IMAGE_FULL):$(VERSION) \
		-t $(IMAGE_FULL):latest \
		.

# Multi-arch build (requires docker buildx, pushes to registry)
build-multiarch:
	@echo "Building multi-arch $(REGISTRY)/$(IMAGE_BASE):$(VERSION)..."
	docker buildx build --platform linux/amd64,linux/arm64 \
		--target base \
		-t $(REGISTRY)/$(IMAGE_BASE):$(VERSION) \
		-t $(REGISTRY)/$(IMAGE_BASE):latest \
		--push .

build-multiarch-full:
	@echo "Building multi-arch $(REGISTRY)/$(IMAGE_FULL):$(VERSION)..."
	docker buildx build --platform linux/amd64,linux/arm64 \
		--target full \
		-t $(REGISTRY)/$(IMAGE_FULL):$(VERSION) \
		-t $(REGISTRY)/$(IMAGE_FULL):latest \
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
	@echo "Container '$(NAME)' started (base image)"
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

run-full:
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
		$(IMAGE_FULL):$(VERSION)
	@echo ""
	@echo "============================================================"
	@echo "Container '$(NAME)' started (full image)"
	@echo "============================================================"
	@echo ""
	@echo "Pigsty is fully deployed and ready to use!"
	@echo ""
	@echo "Access:"
	@echo "  SSH:   ssh root@localhost -p $(SSH_PORT)  (password: pigsty)"
	@echo "  HTTP:  http://localhost:$(HTTP_PORT)"
	@echo "  PGSQL: psql postgres://dbuser_dba@localhost:$(PG_PORT)/postgres"
	@echo ""


#--------------------------------------------------------------#
# Container Lifecycle
#--------------------------------------------------------------#
start:
	docker start $(NAME)

stop:
	@docker stop $(NAME) 2>/dev/null || true

restart:
	@docker restart $(NAME)

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
exec:
	docker exec -it -w /root/pigsty $(NAME) /bin/bash -l

ssh:
	ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		root@localhost -p $(SSH_PORT)

log:
	docker logs -f $(NAME)

status:
	docker exec -it $(NAME) systemctl status

ps:
	docker exec -it $(NAME) ps aux

pass:
	@docker exec $(NAME) grep password /root/pigsty/pigsty.yml 2>/dev/null || echo "No passwords found"

conf:
	docker exec $(NAME) cat /root/pigsty/pigsty.yml


#--------------------------------------------------------------#
# Image Registry Operations
#--------------------------------------------------------------#
pull:
	docker pull --platform=linux/$(ARCH) $(REGISTRY)/$(IMAGE_BASE):$(VERSION)
	docker tag $(REGISTRY)/$(IMAGE_BASE):$(VERSION) $(IMAGE)

pull-full:
	docker pull --platform=linux/$(ARCH) $(REGISTRY)/$(IMAGE_FULL):$(VERSION)
	docker tag $(REGISTRY)/$(IMAGE_FULL):$(VERSION) $(IMAGE_FULL):$(VERSION)

push:
	docker tag $(IMAGE) $(REGISTRY)/$(IMAGE_BASE):$(VERSION)
	docker tag $(IMAGE) $(REGISTRY)/$(IMAGE_BASE):latest
	docker push $(REGISTRY)/$(IMAGE_BASE):$(VERSION)
	docker push $(REGISTRY)/$(IMAGE_BASE):latest

push-full:
	docker tag $(IMAGE_FULL):$(VERSION) $(REGISTRY)/$(IMAGE_FULL):$(VERSION)
	docker tag $(IMAGE_FULL):$(VERSION) $(REGISTRY)/$(IMAGE_FULL):latest
	docker push $(REGISTRY)/$(IMAGE_FULL):$(VERSION)
	docker push $(REGISTRY)/$(IMAGE_FULL):latest


#--------------------------------------------------------------#
# Image Save/Load (for offline transfer)
#--------------------------------------------------------------#
save:
	@echo "Saving $(IMAGE) to $(IMAGE_BASE)-$(VERSION)-$(ARCH).tgz..."
	docker save $(IMAGE) | gzip -c > $(IMAGE_BASE)-$(VERSION)-$(ARCH).tgz

save-full:
	@echo "Saving $(IMAGE_FULL):$(VERSION) to $(IMAGE_FULL)-$(VERSION)-$(ARCH).tgz..."
	docker save $(IMAGE_FULL):$(VERSION) | gzip -c > $(IMAGE_FULL)-$(VERSION)-$(ARCH).tgz

load:
	@echo "Loading from $(IMAGE_BASE)-$(VERSION)-$(ARCH).tgz..."
	gzip -d -c $(IMAGE_BASE)-$(VERSION)-$(ARCH).tgz | docker load

load-full:
	@echo "Loading from $(IMAGE_FULL)-$(VERSION)-$(ARCH).tgz..."
	gzip -d -c $(IMAGE_FULL)-$(VERSION)-$(ARCH).tgz | docker load

rmi:
	docker rmi $(IMAGE) $(IMAGE_LATEST) 2>/dev/null || true

rmi-full:
	docker rmi $(IMAGE_FULL):$(VERSION) $(IMAGE_FULL):latest 2>/dev/null || true


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
        build build-full build-multiarch build-multiarch-full \
        run run-full start stop restart rm clean purge \
        exec ssh log status ps pass conf \
        pull pull-full push push-full \
        save save-full load load-full rmi rmi-full \
        ip inspect top shell test all rebuild
