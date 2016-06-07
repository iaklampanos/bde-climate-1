# Configuration (docker) targets and scripts
SHELL=/bin/bash
CASSANDRA_DATA_DIR_HOST=$(shell echo $$CLIMATE1_CASSANDRA_DATA_DIR)
CASSANDRA_DATA_DIR=/var/lib/cassandra
NETCDF_CASSANDRA_BUILD_DIR=$(shell echo $$CLIMATE1_BUILD_DIR)
NETCDF_DATA_DIR=/home/stathis/Downloads/datainj
GIT=$(shell which git)
GREP=$(shell which grep)
MVN=$(shell which mvn)
JAVA=$(shell which java)
NETCDFS=$(shell ls $(NETCDF_DATA_DIR)/*.nc)
NETCDFCSVS=$(shell ls $(NETCDF_DATA_DIR)/*.csv)
PWD=$(shell pwd)

clean-netcdf::
	#cleaning netcdf-cassandra
	rm -rf $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-cassandra
	$(GIT) clone https://gmouchakis@bitbucket.org/gmouchakis/netcdf-cassandra.git $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-cassandra
	$(MVN) -f $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-cassandra/pom.xml clean package
	#cleaning netcdf-csv
	rm -rf $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-csv
	$(GIT) clone https://gmouchakis@bitbucket.org/gmouchakis/netcdf-csv.git $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-csv
	$(MVN) -f $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-csv/pom.xml clean package
	#cleaning netcdf-queries
	rm -rf $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-queries
	$(GIT) clone https://gmouchakis@bitbucket.org/gmouchakis/netcdf-queries.git $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-queries
	$(MVN) -f $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-queries/pom.xml clean package

cassandra-import::
	##import the netcdf headers to cassandra
	$(JAVA) -jar $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-cassandra/target/netcdf-cassandra-0.0.1-SNAPSHOT-jar-with-dependencies.jar -a 0.0.0.0 -p 8110 $(NETCDFS)   

netcdf-csv::
	#expand netcdf to csv
	for f in $(NETCDFS); do \
	$(JAVA) -jar $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-csv/target/netcdf-csv-0.0.1-SNAPSHOT-jar-with-dependencies.jar $$f $(NETCDF_DATA_DIR)/ ; done 

netcdf-queries::
	#output hive table schema "create table..."
	for f in $(NETCDFS); do \
	CHT=`$(JAVA) -jar $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-queries/target/netcdf-queries-0.0.1-SNAPSHOT-jar-with-dependencies.jar $$f | sed 's|CHAR|CHAR(50)|g'`; \
	echo $$CHT > TEST.TXT;\
	$(DOCKER) exec -it hive beeline -u jdbc:hive2://localhost:10000 -e "$$CHT" ;\
	done;\

BEELINE_PARAMS=""
beeline::
	$(DOCKER) exec -it hive beeline -u jdbc:hive2://localhost:10000 $(BEELINE_PARAMS)

netcdf-hive-import:: netcdf-queries netcdf-csv
	#import csv to hive
	for f in $(NETCDFCSVS); do \
	sed -e 's| ||g' $$f > nospaces.tmp; \
	HFL=`echo $$f | sed -e 's|$(NETCDF_DATA_DIR)/||g'`;\
	$(DOCKER) cp nospaces.tmp hive:/home/$$HFL;\
	TBL=`echo $${f:0:-4}| sed -e 's|\.|_|g' -e 's|-|_|g' -e 's|$(NETCDF_DATA_DIR)/||g'`; \
	$(DOCKER) exec -it hive beeline -u jdbc:hive2://localhost:10000 -e "LOAD DATA LOCAL INPATH '/home/$$HFL' OVERWRITE INTO TABLE $$TBL"; done;
