#
# Создание шаблона БД
# template database Makefile
#
SHELL               = /bin/bash
CFG                 = .env

# on alpine use su-exec
GOSU               ?= gosu

DB_NAME            ?= tpro-template
DB_LOCALE          ?= ru_RU.UTF-8

# dcape container name prefix
DCAPE_PROJECT_NAME ?= dcape
# dcape postgresql container name
DCAPE_DB           ?= $(DCAPE_PROJECT_NAME)_db_1

define CONFIG_DEF
# ------------------------------------------------------------------------------
# pg-skel settings

# Template database name
DB_NAME=$(DB_NAME)

# Template database locale
DB_LOCALE=$(DB_LOCALE)

# dcape postgresql container name
DCAPE_DB=$(DCAPE_DB)

endef
export CONFIG_DEF

# ------------------------------------------------------------------------------

-include $(CFG)
export

.PHONY: all $(CFG) start start-hook stop update docker-wait db-create db-drop help

##
## Цели:
##

all: help

# ------------------------------------------------------------------------------
# webhook commands

start: db-create

start-hook: db-create

stop: db-drop

update: db-create

# ------------------------------------------------------------------------------
# docker

# Wait for postgresql container start
docker-wait:
	@echo -n "Checking PG is ready..."
	@until [[ `docker inspect -f "{{.State.Health.Status}}" $$DCAPE_DB` == healthy ]] ; do sleep 1 ; echo -n "." ; done
	@echo "Ok"

# ------------------------------------------------------------------------------
# DB operations

## create db and load sql
db-create: docker-wait
	@echo "*** $@ ***" ; \
	docker cp ./fts/tsearch_data $$DCAPE_DB:/opt/shared ; \
	docker exec -i $$DCAPE_DB shared-sync.sh ; \
	[[ "$$DB_LOCALE" ]] && DB_LOCALE="-l $$DB_LOCALE" ; \
	echo "Creating $$DB_NAME..." && \
	docker exec -i $$DCAPE_DB $(GOSU) postgres createdb -T template0 $$DB_LOCALE $$DB_NAME || db_exists=1 ; \
	if [[ ! "$$db_exists" ]] ; then \
	  cat setup.sql | docker exec -i $$DCAPE_DB psql -U postgres -d $$DB_NAME -f - ; \
	fi

## drop database
db-drop: docker-wait
	@echo "*** $@ ***"
	@docker exec -i $$DCAPE_DB psql -U postgres -c "UPDATE pg_database SET datistemplate = FALSE WHERE datname = '$$DB_NAME';"
	@docker exec -i $$DCAPE_DB psql -U postgres -c "DROP DATABASE \"$$DB_NAME\";" || true

# ------------------------------------------------------------------------------

## create initial config
$(CFG):
	@echo "$$CONFIG_DEF" > $@

# ------------------------------------------------------------------------------

## List Makefile targets
help:
	@grep -A 1 "^##" Makefile | less

##
## Press 'q' for exit
##
