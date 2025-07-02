#!/usr/bin/make

# Registry app management commands
APP = registry
APP_DIR = /opt/$(APP)
DATA_DIR = /data/$(APP)

#==============================================================#
# Docker Registry Mirror Management
#==============================================================#

default: up

# create required directories
dir:
	mkdir -p $(DATA_DIR)


# launch the registry service
up: dir conf
	cd $(APP_DIR) && docker compose up -d

# stop the registry service  
down:
	cd $(APP_DIR) && docker compose down

# restart the registry service
restart: down up

# remove the registry service and data
clean: down
	cd $(APP_DIR) && docker compose down -v
	rm -rf $(DATA_DIR)/*

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
	@curl -f http://localhost:5000/v2/ && echo "Registry is healthy" || echo "Registry is not responding"

# show registry catalog
catalog:
	@echo "Registry catalog:"
	@curl -s http://localhost:5000/v2/_catalog | jq '.' 2>/dev/null || curl -s http://localhost:5000/v2/_catalog

# backup registry data
backup:
	@echo "Backing up registry data..."
	tar -czf $(DATA_DIR)_backup_$(shell date +%Y%m%d_%H%M%S).tar.gz -C $(DATA_DIR) .

# show disk usage
du:
	@echo "Registry data disk usage:"
	@du -sh $(DATA_DIR) 2>/dev/null || echo "Data directory not found"

# clean up unused data
prune:
	cd $(APP_DIR) && docker system prune -f
	cd $(APP_DIR) && docker volume prune -f

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
	@echo "  clean    - Remove service and data"
	@echo "  health   - Test registry health"
	@echo "  catalog  - Show registry catalog"
	@echo "  backup   - Backup registry data"
	@echo "  du       - Show disk usage"
	@echo "  prune    - Clean up unused data"

.PHONY: default dir conf up down restart clean status log pull health catalog backup du prune help