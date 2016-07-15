#Conf target and scripts
DOCKER=$(shell which docker)
DATASET=somedataset
PROV_ID=someprovid
REG=d01
DAY=07
EDG=max

hive-query-daily-indx::
	t2res=`docker  exec -i hive beeline --silent -u jdbc:hive2://localhost:10000 -e "select max(t2), min(t2) from wrfout_$(REG)_2016_07_$(DAY)_00_00_00_t2"`;echo $$t2res;




hive-hangout-query-max::
	t2res=`docker  exec -i hive beeline -u jdbc:hive2://localhost:10000 -e "select max(wrfout_d02_2016_07_07_00_00_00_t2.t2 - wrfout_d02_2016_07_06_00_00_00_t2.t2) as maxt2 from wrfout_d02_2016_07_07_00_00_00_t2, wrfout_d02_2016_07_06_00_00_00_t2 where wrfout_d02_2016_07_06_00_00_00_t2.row_no = wrfout_d02_2016_07_07_00_00_00_t2.row_no"`;echo $$t2res | grep maxt2;

hive-hangout-query-min::
	t2res=`docker  exec -i hive beeline -u jdbc:hive2://localhost:10000 -e "select min(wrfout_d02_2016_07_07_00_00_00_t2.t2 - wrfout_d02_2016_07_06_00_00_00_t2.t2) as mint2 from wrfout_d02_2016_07_07_00_00_00_t2, wrfout_d02_2016_07_06_00_00_00_t2 where wrfout_d02_2016_07_06_00_00_00_t2.row_no = wrfout_d02_2016_07_07_00_00_00_t2.row_no"`;echo $$t2res | grep mint2;


get-prov-tree::
	res=`$(DOCKER) exec -i bdeclimate1_cassandra_1 cqlsh -e "select json id,parentid, bparentid, user, paramset, type, downscaling, createdat, lasteditedat, paths from testprov.prov where id=$(PROV_ID) limit 1" | tail -n+4 | head -n-2`;\
	echo $$res;

get-prov::
	res=`$(DOCKER) exec -i bdeclimate1_cassandra_1 cqlsh -e "select json id,parentid, bparentid, user, paramset, type, downscaling, createdat, lasteditedat, paths from testprov.prov where paths contains '$(DATASET)'  limit 1 allow filtering" | tail -n+4 | head -n-2`;\
	echo $$res;\
	if [ "$$res" = "" ]; then exit; fi;\
        id_par=`python -c "import json;print json.loads('$$res')['parentid'];"`;\
	id_bpar=`python -c "import json;print json.loads('$$res')['bparentid'];"`;\
	if [ "$$id_bpar" != "None" ] || [ "$$id_par" != "None" ]; then\
	  while true; do\
	    if [ "$$id_par" != "None" ]; then\
	      make -s get-prov-tree PROV_ID=$$id_par;\
	      id_pares=`make -s get-prov-tree PROV_ID=$$id_par`;\
	      id_par=`python -c "import json;print json.loads('$$id_pares')['parentid'];"`;\
	    fi;\
	    if [ "$$id_bpar" !=  "None" ]; then\
	      make -s get-prov-tree PROV_ID=$$id_bpar;\
	      id_bpares=`make -s get-prov-tree PROV_ID=$$id_bpar`;\
	      id_bpar=`python -c "import json;print json.loads('$$id_bpares')['bparentid'];"`;\
	    fi;\
	    if [ "$$id_bpar" = "None" ] && [ "$$id_par" = "None" ]; then\
	      break;\
	    fi;\
	  done;\
	fi;
