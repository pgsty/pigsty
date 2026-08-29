#!/usr/bin/make
SHELL := /bin/bash -e -o pipefail

# Registry app management commands
APP_DIR ?= $(CURDIR)
export APP_DIR

#==============================================================#
# Docker Registry Mirror Management
#==============================================================#

default: up

# create required directories
dir:
	@data_dir="$${DATA_DIR-$$(cd "$$APP_DIR" && docker compose config --format json | jq -er '.services.registry.volumes[] | select(.type == "bind" and .target == "/var/lib/registry") | .source | split("$$$$") | join("$$")')}"; test -n "$$data_dir"; mkdir -p -- "$$data_dir"

# show effective registry configuration
conf:
	@cd "$$APP_DIR" && docker compose config --format json | jq -r '.services.registry as $$app | {REGISTRY_IMAGE: $$app.image, REGISTRY_UI_IMAGE: .services["registry-ui"].image, REGISTRY_DATA: ($$app.volumes[] | select(.target == "/var/lib/registry") | .source), REGISTRY_PORT: ($$app.ports[] | select(.target == 5000) | .published), REGISTRY_UI_PORT: (.services["registry-ui"].ports[] | select(.target == 80) | .published), REGISTRY_NO_PROXY: $$app.environment.NO_PROXY} + ($$app.environment | with_entries(select(.key | test("^REGISTRY_(STORAGE_DELETE_ENABLED|LOG_LEVEL|PROXY_REMOTEURL|PROXY_TTL)$$")))) | to_entries[] | "\(.key)=\(.value)" | split("$$$$") | join("$$")'


# launch the registry service
up: dir conf
	cd "$$APP_DIR" && docker compose up -d

# stop the registry service  
down:
	cd "$$APP_DIR" && docker compose down

# restart the registry service
restart: down up

# remove the registry service; cached data is preserved
clean:
	cd "$$APP_DIR" && docker compose down

# explicitly remove all cached registry data
purge: clean
	@data_dir="$${DATA_DIR-$$(cd "$$APP_DIR" && docker compose config --format json | jq -er '.services.registry.volumes[] | select(.type == "bind" and .target == "/var/lib/registry") | .source | split("$$$$") | join("$$")')}"; test -n "$$data_dir"; test "$$data_dir" != "/"; rm -rf -- "$$data_dir"/*

# show registry service status
status:
	cd "$$APP_DIR" && docker compose ps

# show registry service logs
log:
	cd "$$APP_DIR" && docker compose logs -f

# pull the registry image
pull:
	cd "$$APP_DIR" && docker compose pull

# test registry health
health:
	@echo "Testing registry health..."
	@port="$$(cd "$$APP_DIR" && docker compose config --format json | jq -er '.services.registry.ports[] | select(.target == 5000) | .published')"; curl -fsS "http://127.0.0.1:$$port/v2/"; echo "Registry is healthy"

# show registry catalog
catalog:
	@echo "Registry catalog:"
	@port="$$(cd "$$APP_DIR" && docker compose config --format json | jq -er '.services.registry.ports[] | select(.target == 5000) | .published')"; curl -fsS "http://127.0.0.1:$$port/v2/_catalog" | jq '.'

# backup registry data
backup:
	@echo "Backing up registry data..."
	@data_dir="$${DATA_DIR-$$(cd "$$APP_DIR" && docker compose config --format json | jq -er '.services.registry.volumes[] | select(.type == "bind" and .target == "/var/lib/registry") | .source | split("$$$$") | join("$$")')}"; test -n "$$data_dir"; tar -czf "$${data_dir}_backup_$$(date +%Y%m%d_%H%M%S).tar.gz" -C "$$data_dir" .

# show disk usage
du:
	@echo "Registry data disk usage:"
	@data_dir="$${DATA_DIR-$$(cd "$$APP_DIR" && docker compose config --format json | jq -er '.services.registry.volumes[] | select(.type == "bind" and .target == "/var/lib/registry") | .source | split("$$$$") | join("$$")')}"; test -n "$$data_dir"; du -sh -- "$$data_dir" 2>/dev/null || echo "Data directory not found"

#==============================================================#
# Helper commands
#==============================================================#

# display help information
help:
	@echo "Available commands:"
	@echo "  up       - Start registry service"
	@echo "  down     - Stop registry service"  
	@echo "  restart  - Restart registry service"
	@echo "  status   - Show service status"
	@echo "  log      - Show service logs"
	@echo "  clean    - Remove services while preserving registry data"
	@echo "  purge    - Remove services and all registry data"
	@echo "  health   - Test registry health"
	@echo "  catalog  - Show registry catalog"
	@echo "  backup   - Backup registry data"
	@echo "  du       - Show disk usage"

.PHONY: default dir conf up down restart clean purge status log pull health catalog backup du help
