#Configuration (docker) targets and scripts

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
USERNAM=bde2020
MODELSRV=tornado.ipta.demokritos.gr
CUSER=$(shell whoami)
MAKEOPTS=


conf-help::
	@echo $(MAKEOPTS)

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
	$(DOCKER) network create hadoop 
	#$(GIT) clone https://github.com/big-data-europe/docker-hadoop $(DOCKERCOMPOSE_BUILD_DIR)/docker-hadoop
	#$(GIT) clone https://github.com/big-data-europe/docker-hive $(DOCKERCOMPOSE_BUILD_DIR)/docker-hive

compose-hadoop-hive-non::
	###Executing hadoop, hive compose
	cd $(DOCKERCOMPOSE_BUILD_DIR)/docker-hadoop && $(DOCKERCOMPOSE) up -d
	cd $(DOCKERCOMPOSE_BUILD_DIR)/docker-hive && $(DOCKERCOMPOSE) up -d


compose-hadoop-hive:: init-hadoop-hive
	###Executing hadoop, hive compose
	cd $(DOCKERCOMPOSE_BUILD_DIR)/docker-hadoop && $(DOCKERCOMPOSE) up -d
	cd $(DOCKERCOMPOSE_BUILD_DIR)/docker-hive && $(DOCKERCOMPOSE) up -d

compose:: init compose-hadoop-hive
	### Executing docker-compose:
	$(DOCKERCOMPOSE) -f $(DOCKERCOMPOSE_YML) up -d && make create-cassandra-schema;

create-cassandra-schema::
	rm -rf $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-cassandra;\
	$(GIT) clone https://grstathis@bitbucket.org/grstathis/netcdf-cassandra-st.git $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-cassandra;\
	$(MVN) -f $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-cassandra/pom.xml clean package;\
	sleep 15; \
	$(JAVA) -jar $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-cassandra/target/netcdf-cassandra-0.0.1-SNAPSHOT-jar-with-dependencies.jar -i -a 0.0.0.0 -p 8110;\
	$(DOCKER) cp prov/create_prov_schema.cql bdeclimate1_cassandra_1:/home/;\
	$(DOCKER) exec -it bdeclimate1_cassandra_1 cqlsh -f /home/create_prov_schema.cql;		

configure-start-semagrow:: create-cassandra-schema
	#configure semagrow to talk to cassandra
	VIP=`$(DOCKER) network inspect hadoop | grep -A3 bdeclimate1_cassandra_1 | tail -n1 | sed 's/[",:,IPv4Address]//g'|head -c-4`;\
	rm -rf $(NETCDF_CASSANDRA_BUILD_DIR)/docker-sevod-scraper; \
	$(GIT) clone https://github.com/semagrow/docker-sevod-scraper $(NETCDF_CASSANDRA_BUILD_DIR)/docker-sevod-scraper;\
	cd $(NETCDF_CASSANDRA_BUILD_DIR)/docker-sevod-scraper && $(DOCKER) build -t sevod-scraper .;\
	$(DOCKER) run --rm --net=hadoop -it -v $(NETCDF_DATA_DIR):/output sevod-scraper cassandra $$VIP 9042 netcdf_headers http://cassandra.semagrow.eu /output/metadata.ttl &&\
	$(DOCKER) run -d --net=hadoop -p 8090:8080 -v $(NETCDF_DATA_DIR):/etc/default/semagrow semagrow/semagrow-cassandra;

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
	$(DOCKER) network rm hadoop
ps::
	$(DOCKER) ps

clean:: conf-clean
conf-clean::
	### Cleaning the configuration
	rm -f $(DOCKERCOMPOSE_YML)
	rm -f $(DOCKERFILE)

create-structure::
	### Copy Dir and structure
	scp bde2020user1.tar.gz $(USERNAM)@$(MODELSRV):~/; \
	CURRUUID=`uuidgen`; \
	ssh $(USERNAM)@$(MODELSRV) " tar zxf bde2020user1.tar.gz && mv bde2020user1 $(CUSER)_$$CURRUUID"; \
	echo $(CUSER)_$$CURRUUID > "$(CUSER)_"curr.UUID;\
	echo "CURR_USER_ID_ "$(CUSER)_$$CURRUUID; 



CONTAINER=bdeclimate1_climate1_1
ssh:: ssh-container
ssh-container::
	$(DOCKER) exec -it $(CONTAINER) /bin/bash

logs::
	$(DOCKER) logs $(CONTAINER)
