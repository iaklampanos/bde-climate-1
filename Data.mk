# Configuration (docker) targets and scripts
SHELL=/bin/bash
CASSANDRA_DATA_DIR_HOST=$(shell echo $$CLIMATE1_CASSANDRA_DATA_DIR)
CASSANDRA_DATA_DIR=/var/lib/cassandra
NETCDF_CASSANDRA_BUILD_DIR=$(shell echo $$CLIMATE1_BUILD_DIR)
NETCDF_DATA_DIR=/home/stathis/Downloads/datainj2
GIT=$(shell which git)
GREP=$(shell which grep)
MVN=$(shell which mvn)
JAVA=$(shell which java)
NETCDFS=$(shell ls $(NETCDF_DATA_DIR)/*.nc)
NETCDFCSVS=$(shell ls $(NETCDF_DATA_DIR)/*.gz)
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
	$(DOCKER) exec -it bdeclimate1_cassandra_1 cqlsh -e "CREATE TABLE IF NOT EXISTS netcdf_headers.dataset_times ( dataset text, start_date text,end_date text, step text, PRIMARY KEY (dataset));";\
	for f in $(NETCDFS); do \
	$(JAVA) -jar $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-cassandra/target/netcdf-cassandra-0.0.1-SNAPSHOT-jar-with-dependencies.jar -i -a 0.0.0.0 -p 8110 -f $$f;FN=`basename $$f`;\
	STRDAT=`ncks -v Times $$f | grep -F Time[0] | cut -d "=" -f2| sed "s/'//g"`;\
	ENDDAT=`ncks -v Times $$f | tail -n2 | head -n1 | cut -d "=" -f2| sed "s/'//g"`; \
	STEPDAT=`ncks -v Times $$f | grep "Times dimension 0:" | cut -d "=" -f2 | sed 's/(Record non-coordinate dimension)//g;s/ //g'`;\
	$(DOCKER) exec -it bdeclimate1_cassandra_1 cqlsh -e "INSERT INTO netcdf_headers.dataset_times (dataset, start_date, end_date, step) VALUES('$$FN', '$$STRDAT', '$$ENDDAT','$$STEPDAT');";\
	done;  

netcdf-csv::
	#expand netcdf to csv
	for f in $(NETCDFS); do \
	$(JAVA) -jar $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-csv/target/netcdf-csv-0.0.1-SNAPSHOT-jar-with-dependencies.jar -c -i $$f -o $(NETCDF_DATA_DIR)/ ; done 

netcdf-queries::
	#output hive table schema "create table..."
	for f in $(NETCDFS); do \
	CHT=`$(JAVA) -jar $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-queries/target/netcdf-queries-0.0.1-SNAPSHOT-jar-with-dependencies.jar $$f | sed 's|:|_|g;s|CREATE TABLE|CREATE TABLE IF NOT EXISTS|g'`;echo $$CHT;\
	$(DOCKER) exec -it hive beeline -u jdbc:hive2://localhost:10000 -e "$$CHT" ;\
	done;

BEELINE_PARAMS=""
beeline::
	$(DOCKER) exec -it hive beeline -u jdbc:hive2://localhost:10000 $(BEELINE_PARAMS)

netcdf-hive-import:: netcdf-queries netcdf-csv 
	#import csv to hive
	for f in $(NETCDFCSVS); do \
	HFL=`echo $$f | sed -e 's|$(NETCDF_DATA_DIR)/||g;s|-|_|g;s|:|_|g'`;\
	$(DOCKER) cp $$f hive:/home/$$HFL;\
	TBL=`echo $${HFL:0:-7}| sed -e 's|\.|_|g' -e 's|-|_|g;s|:|_|g' -e 's|$(NETCDF_DATA_DIR)/||g'`;\
	$(DOCKER) exec -it hive beeline -u jdbc:hive2://localhost:10000 -e "LOAD DATA LOCAL INPATH '/home/$$HFL' OVERWRITE INTO TABLE $$TBL";done;

#ingestion of netcdfs in dir NETCDF_DATA_DIR
ingest:: cassandra-import netcdf-hive-import


