#!/usr/bin/make

# Registry app management commands
APP = registry
APP_DIR ?= $(CURDIR)

-include .env
REGISTRY_DATA ?= /data/$(APP)
DATA_DIR ?= $(REGISTRY_DATA)
REGISTRY_PORT ?= 5000

#==============================================================#
# Docker Registry Mirror Management
#==============================================================#

default: up

# create required directories
dir:
	mkdir -p $(DATA_DIR)

# show effective registry configuration
conf:
	@grep -E '^(REGISTRY_IMAGE|REGISTRY_UI_IMAGE|REGISTRY_DATA|REGISTRY_PORT|REGISTRY_UI_PORT|REGISTRY_STORAGE_DELETE_ENABLED|REGISTRY_LOG_LEVEL|REGISTRY_PROXY_REMOTEURL|REGISTRY_PROXY_TTL)=' .env 2>/dev/null || true


# launch the registry service
up: dir conf
	cd $(APP_DIR) && docker compose up -d

# stop the registry service  
down:
	cd $(APP_DIR) && docker compose down

# restart the registry service
restart: down up

# remove the registry service; cached data is preserved
clean:
	cd $(APP_DIR) && docker compose down -v

# explicitly remove all cached registry data
purge: clean
	@test -n "$(DATA_DIR)" && test "$(DATA_DIR)" != "/"
	rm -rf -- "$(DATA_DIR)"/*

# show registry service status
status:
	cd $(APP_DIR) && docker compose ps

# show registry service logs
log:
	cd $(APP_DIR) && docker compose logs -f

# pull the registry image
pull:
	cd $(APP_DIR) && docker compose pull

# test registry health
health:
	@echo "Testing registry health..."
	@curl -f http://localhost:$(REGISTRY_PORT)/v2/ && echo "Registry is healthy" || echo "Registry is not responding"

# show registry catalog
catalog:
	@echo "Registry catalog:"
	@curl -s http://localhost:$(REGISTRY_PORT)/v2/_catalog | jq '.' 2>/dev/null || curl -s http://localhost:$(REGISTRY_PORT)/v2/_catalog

# backup registry data
backup:
	@echo "Backing up registry data..."
	tar -czf $(DATA_DIR)_backup_$(shell date +%Y%m%d_%H%M%S).tar.gz -C $(DATA_DIR) .

# show disk usage
du:
	@echo "Registry data disk usage:"
	@du -sh $(DATA_DIR) 2>/dev/null || echo "Data directory not found"

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
