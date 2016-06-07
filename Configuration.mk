# Configuration (docker) targets and scripts

SHELL=/bin/bash
DOCKERCOMPOSE=$(shell which docker-compose)
DOCKER=$(shell which docker)
DOCKERMACHINE=$(shell which docker-machine)
DOCKERFILE_TEMPLATE=templates/Dockerfile.template
TEMPL_DOCKERFILE_WORKDIR=__WORKDIR_

DOCKERCOMPOSE_TEMPLATE=templates/climate1_compose.template
DOCKERCOMPOSE_BUILD_DIR=$(shell echo $$CLIMATE1_BUILD_DIR)
DOCKERFILE=$(DOCKERCOMPOSE_BUILD_DIR)Dockerfile
TEMPL_CASS_DATA_HOST=__HOST_CASSANDRA_DATA_
TEMPL_CASS_DATA=__CASSANDRA_DATA_
TEMPL_BUILD_DIR=__BUILD_DIR_
DOCKERCOMPOSE_YML=climate1_compose.yml
CASSANDRA_DATA_DIR_HOST=$(shell echo $$CLIMATE1_CASSANDRA_DATA_DIR)
CASSANDRA_DATA_DIR=/var/lib/cassandra

$(DOCKERCOMPOSE_YML):
	### Creating the docker-compose yml
	cat $(DOCKERCOMPOSE_TEMPLATE) | $(SED) 's|$(TEMPL_CASS_DATA)|$(CASSANDRA_DATA_DIR)|g;s|$(TEMPL_CASS_DATA_HOST)|$(CASSANDRA_DATA_DIR_HOST)|g;s|$(TEMPL_BUILD_DIR)|$(DOCKERCOMPOSE_BUILD_DIR)|g' $(DOCKERCOMPOSE_TEMPLATE) > $@

$(DOCKERFILE):
	### Creating the dockerfile
	cat $(DOCKERFILE_TEMPLATE) | $(SED) 's|$(TEMPL_DOCKERFILE_WORKDIR)|$(DOCKERCOMPOSE_BUILD_DIR)|g' > $@

init:: $(DOCKERCOMPOSE_YML) $(DOCKERFILE)
	@echo $(CASSANDRA_DATA_DIR_HOST)
	### Create the cassandra data dir; if it doesn't exist
	mkdir -p $(CASSANDRA_DATA_DIR_HOST)

login::
	$(DOCKER) login

init-hadoop-hive::
	### Create hadoop network,clone repos for hadoop, hive
	$(DOCKER) network rm hadoop
	$(DOCKER) network create hadoop
	#$(GIT) clone https://github.com/big-data-europe/docker-hadoop $(DOCKERCOMPOSE_BUILD_DIR)/docker-hadoop
	#$(GIT) clone https://github.com/big-data-europe/docker-hive $(DOCKERCOMPOSE_BUILD_DIR)/docker-hive

compose-hadoop-hive:: init-hadoop-hive
	###Executing hadoop, hive compose
	cd $(DOCKERCOMPOSE_BUILD_DIR)/docker-hadoop && $(DOCKERCOMPOSE) up -d
	cd $(DOCKERCOMPOSE_BUILD_DIR)/docker-hive && $(DOCKERCOMPOSE) up -d

compose:: init compose-hadoop-hive
	### Executing docker-compose:
	$(DOCKERCOMPOSE) -f $(DOCKERCOMPOSE_YML) up -d
	### Let's see what's running:
	$(DOCKER) ps

stop:: stop-all
stop-all::
	### Stop all containers individually:
	$(DOCKER) stop $$($(DOCKER) ps -a -q)

kill::
	### docker-compose kill
	$(DOCKERCOMPOSE) -f $(DOCKERCOMPOSE_YML) kill

rm-all::
	###Delete all containers###
	$(DOCKER) rm -f $$($(DOCKER) ps -a -q)
ps::
	$(DOCKER) ps

clean:: conf-clean
conf-clean::
	### Cleaning the configuration
	rm -f $(DOCKERCOMPOSE_YML)
	rm -f $(DOCKERFILE)

CONTAINER=bdeclimate1_climate1_1
ssh:: ssh-container
ssh-container::
	$(DOCKER) exec -it $(CONTAINER) /bin/bash

logs::
	$(DOCKER) logs $(CONTAINER)
