# Configuration (docker) targets and scripts
SHELL=/bin/bash
CASSANDRA_DATA_DIR_HOST=$(shell echo $$CLIMATE1_CASSANDRA_DATA_DIR)
CASSANDRA_DATA_DIR=/var/lib/cassandra
NETCDF_CASSANDRA_BUILD_DIR=$(shell echo $$CLIMATE1_BUILD_DIR)
NETCDF_DATA_DIR=$(shell echo $$CLIMATE1_CASSANDRA_DATA_DIR)
GIT=$(shell which git)
GREP=$(shell which grep)
MVN=$(shell which mvn)
JAVA=$(shell which java)
NETCDFS=$(shell ls $(NETCDF_DATA_DIR)/*.nc)
NETCDFCSVS=$(shell ls $(NETCDF_DATA_DIR)/*.gz)
PWD=$(shell pwd)
NETCDFFILE=ncfile/default/expects/usr/agr
NETCDFOUT=out.nc

clean-netcdf-all::
	#cleaning netcdf-cassandra
	rm -rf $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-cassandra
	$(GIT) clone https://grstathis@bitbucket.org/grstathis/netcdf-cassandra-st.git $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-cassandra
	$(MVN) -f $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-cassandra/pom.xml clean package
	#cleaning netcdf-csv
	rm -rf $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-csv
	$(GIT) clone https://gmouchakis@bitbucket.org/gmouchakis/netcdf-csv.git $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-csv
	$(MVN) -f $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-csv/pom.xml clean package
	#cleaning netcdf-queries
	rm -rf $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-queries
	$(GIT) clone https://gmouchakis@bitbucket.org/gmouchakis/netcdf-queries.git $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-queries
	$(MVN) -f $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-queries/pom.xml clean package
	rm -rf $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-hive
	$(GIT) clone https://grstathis@bitbucket.org/grstathis/netcdf-hive-st.git $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-hive
	$(MVN) -f $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-hive/pom.xml clean package
	rm -rf $(NETCDF_CASSANDRA_BUILD_DIR)/NetCDFDirectExport
	$(GIT) clone https://grstathis@bitbucket.org/grstathis/netcdfdirectexport.git $(NETCDF_CASSANDRA_BUILD_DIR)/NetCDFDirectExport
	$(MVN) -f $(NETCDF_CASSANDRA_BUILD_DIR)/NetCDFDirectExport/pom.xml clean package



cassandra-import::
	##import the netcdf headers to cassandra
	$(DOCKER) exec -it bdeclimate1_cassandra_1 cqlsh -e "CREATE TABLE IF NOT EXISTS netcdf_headers.dataset_times ( dataset text, start_date text,end_date text, step text, PRIMARY KEY (dataset));";\
	$(JAVA) -jar $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-cassandra/target/netcdf-cassandra-0.0.1-SNAPSHOT-jar-with-dependencies.jar -i -a 0.0.0.0 -p 8110 -f $(NETCDFFILE);FN=`basename $(NETCDFFILE)`;\
	STRDAT=`ncks -v Times $(NETCDFFILE) | grep -F Time[0] | cut -d "=" -f2| sed "s/'//g"`;\
	ENDDAT=`ncks -v Times $(NETCDFFILE) | tail -n2 | head -n1 | cut -d "=" -f2| sed "s/'//g"`; \
	STEPDAT=`ncks -v Times $(NETCDFFILE) | grep "Times dimension 0:" | cut -d "=" -f2 | sed 's/(Record non-coordinate dimension)//g;s/ //g'`;\
	$(DOCKER) exec -it bdeclimate1_cassandra_1 cqlsh -e "INSERT INTO netcdf_headers.dataset_times (dataset, start_date, end_date, step) VALUES('$$FN', '$$STRDAT', '$$ENDDAT','$$STEPDAT');";\



cassandra-import-all::
	for f in $(NETCDFS); do \
		make cassandra-import NETCDFFILE=$$f;\
	done;  

netcdf-csv::
	#expand netcdf to csv
	rm $(NETCDF_DATA_DIR)/*.gz;\
	$(JAVA) -jar $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-csv/target/netcdf-csv-0.0.1-SNAPSHOT-jar-with-dependencies.jar -c -i $(NETCDFFILE) -o $(NETCDF_DATA_DIR)/; 

netcdf-csv-all::
	for f in $(NETCDFS); do \
		make netcdf-csv NETCDFFILE=$$f;\
	done;

netcdf-queries::
	CHT=`$(JAVA) -jar $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-queries/target/netcdf-queries-0.0.1-SNAPSHOT-jar-with-dependencies.jar $(NETCDFFILE) | sed 's|:|_|g;s|CREATE TABLE|CREATE TABLE IF NOT EXISTS|g'`;\
	$(DOCKER) exec -it hive beeline -u jdbc:hive2://localhost:10000 -e "$$CHT" ;


netcdf-queries-all::
	#output hive table schema "create table..."
	for f in $(NETCDFS); do \
		make netcdf-queries NETCDFFILE=$$f;\
	done;

BEELINE_PARAMS=""
beeline::
	$(DOCKER) exec -it hive beeline -u jdbc:hive2://localhost:10000 $(BEELINE_PARAMS)

netcdf-hive-import::
	HFL=`basename $(NETCDFFILE) | sed -e 's|$(NETCDF_DATA_DIR)/||g;s|-|_|g;s|:|_|g'`;echo $$HFL;\
	$(DOCKER) cp $(NETCDFFILE) hive:/home/$$HFL;\
	TBL=`echo $${HFL:0:-7}| sed -e 's|\.|_|g' -e 's|-|_|g;s|:|_|g' -e 's|$(NETCDF_DATA_DIR)/||g'`; echo $$TBL;\
	$(DOCKER) exec -it hive beeline -u jdbc:hive2://localhost:10000 -e "LOAD DATA LOCAL INPATH '/home/$$HFL' OVERWRITE INTO TABLE $$TBL";

netcdf-hive-import-all:: 
	#import csv to hive
	for f in $(NETCDFCSVS); do \
		make netcdf-hive-import NETCDFFILE=$$f;\
	done;


get-dataset::
	$(DOCKER) exec -it cassandra cqlsh -

#ingestion of netcdf file
#usage make ingest-file NETCDFFILE=yourfilewithfullpath 
ingest-file:: cassandra-import netcdf-queries netcdf-csv netcdf-hive-import-all

#export of netcdf file
#usage make export-file NETCDFKEY=yourkeysearch NETCDFOUT=nameofnetcdfoutfile
export-file::
	HIVEIP=`$(DOCKER) network inspect hadoop | grep hive -n3 | tail -n1 |  grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b";`;HIP=`echo $$HIVEIP`; echo $$HIP;\
	$(JAVA) -jar $(NETCDF_CASSANDRA_BUILD_DIR)/NetCDFDirectExport/target/NetCDFDirectExport-0.0.1-SNAPSHOT-jar-with-dependencies.jar -a 0.0.0.0 -p 8110 -t $(NETCDFKEY)  -d$$HIVEIP -o $(NETCDFOUT)


