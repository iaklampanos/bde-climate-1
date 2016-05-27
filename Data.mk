# Configuration (docker) targets and scripts
SHELL=/bin/bash
CASSANDRA_DATA_DIR_HOST=$(shell echo $$CLIMATE1_CASSANDRA_DATA_DIR)
CASSANDRA_DATA_DIR=/var/lib/cassandra
NETCDF_CASSANDRA_BUILD_DIR=$(shell echo $$CLIMATE1_BUILD_DIR)
NETCDF_DATA_DIR=/home/stathis/Downloads/netcdft
GIT=$(shell which git)
MVN=$(shell which mvn)
JAVA=$(shell which java)
NETCDFS=$(shell ls $(NETCDF_DATA_DIR)/*.nc)


clean-build::
	#cleaning netcdf-cassandra
	rm -rf $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-cassandra
	$(GIT) clone https://gmouchakis@bitbucket.org/gmouchakis/netcdf-cassandra.git $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-cassandra
	#cleaning netcdf-csv
	rm -rf $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-csv
	$(GIT) clone https://gmouchakis@bitbucket.org/gmouchakis/netcdf-csv.git $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-csv
	#cleaning netcdf-queries
	rm -rf $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-queries
	$(GIT) clone https://gmouchakis@bitbucket.org/gmouchakis/netcdf-queries.git $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-queries



cassandra-import::
	##import the netcdf headers to cassandra
	$(MVN) -f $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-cassandra/pom.xml clean package
	$(JAVA) -jar $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-cassandra/target/netcdf-cassandra-0.0.1-SNAPSHOT-jar-with-dependencies.jar 0.0.0.0 8110 $(NETCDFS)   

netcdf-csv::
	#expand netcdf to csv
	$(MVN) -f $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-csv/pom.xml clean package
	$(JAVA) -jar $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-csv/target/netcdf-csv-0.0.1-SNAPSHOT-jar-with-dependencies.jar $(NETCDF_LST) $(NETCDF_DATA_DIR) 

netcdf-queries::
	#output hive table schema "create table..."
	$(MVN) -f $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-queries/pom.xml clean package
	for f in $(NETCDFS); do \
	  $(JAVA) -jar $(NETCDF_CASSANDRA_BUILD_DIR)/netcdf-queries/target/netcdf-queries-0.0.1-SNAPSHOT-jar-with-dependencies.jar $$f; \
	done

netcdf-hive::

	

