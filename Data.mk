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
NETCDF_CASSANDRA_BUILD_DIR=$(shell echo $$CLIMATE1_BUILD_DIR)
NETCDF_DATA_DIR=/home/stathis/Downloads

$(NETCDF_LST):
	NETCDFS=$(shell ls $(NETCDF_DATA_DIR)/*.nc)


cassandra-import::
	##import the netcdf headers to cassandra
	rm -rf $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-cassandra
	$(GIT) clone https://gmouchakis@bitbucket.org/gmouchakis/netcdf-cassandra.git $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-cassandra
	$(MVN) -f $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-cassandra/pom.xml clean package
	$(JAVA) -jar $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-cassandra/target/netcdf-cassandra-0.0.1-SNAPSHOT-jar-with-dependencies.jar 0.0.0.0 8110 $(NETCDF_LST)   

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

compose:: init
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
