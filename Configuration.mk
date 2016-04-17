# Configuration (docker) targets and scripts

SHELL=/bin/bash
DOCKERCOMPOSE=/usr/local/bin/docker-compose
DOCKER=/usr/local/bin/docker
DOCKERMACHINE=/usr/local/bin/docker-machine

DOCKERCOMPOSE_TEMPLATE=scripts/climate1_compose.template
DOCKERCOMPOSE_BUILD_DIR=/Users/iraklis/Climate1-build/
TEMPL_CASS_DATA_HOST=__HOST_CASSANDRA_DATA_
TEMPL_CASS_DATA=__CASSANDRA_DATA_
TEMPL_BUILD_DIR=__BUILD_DIR_
DOCKERCOMPOSE_YML=scripts/climate1_compose.yml
CASSANDRA_DATA_DIR_HOST=/Users/iraklis/Climate1_Vols/cassandra_data
CASSANDRA_DATA_DIR=/var/lib/cassandra

$(DOCKERCOMPOSE_YML):
	#
	### Creating the docker-compose yml
	####################################
	cat $(DOCKERCOMPOSE_TEMPLATE) | $(SED) 's|$(TEMPL_CASS_DATA)|$(CASSANDRA_DATA_DIR)|g;s|$(TEMPL_CASS_DATA_HOST)|$(CASSANDRA_DATA_DIR_HOST)|g;s|$(TEMPL_BUILD_DIR)|$(DOCKERCOMPOSE_BUILD_DIR)|g' $(DOCKERCOMPOSE_TEMPLATE) > $@

init:: $(DOCKERCOMPOSE_YML)
	#
	### Create the cassandra data dir; if it doesn't exist
	#######################################################
	mkdir -p $(CASSANDRA_DATA_DIR_HOST)


login::
	$(DOCKER) login

### docker composition for development, testing and demonstration
compose:: init ps
	@echo

ps::
	$(DOCKER) ps

conf-clean::
	#
	### Cleaning the configuration
	###############################
	rm $(DOCKERCOMPOSE_YML)
