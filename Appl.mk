#Conf target and scripts
DOCKER=$(shell which docker)
DATASET=somedataset
PROV_ID=someprovid
REG=d01
DAY=07
EDG=max

hive-query-daily-indx::
	t2res=`docker  exec -i hive beeline --silent -u jdbc:hive2://localhost:10000 -e "select max(t2), min(t2) from wrfout_$(REG)_2016_07_$(DAY)_00_00_00_t2"`;echo $$t2res;


hive-query-max-diff-t2-fill::
	docker  exec -i hive beeline -u jdbc:hive2://localhost:10000 -e "create table if not exists wrfout_d02_p1_maxt2 as select 0  as time, south_north, west_east, max(t2) as maxt2 from wrfout_d02_2016_07_01_00_00_00_t2 group by south_north, west_east; insert overwrite table wrfout_d02_p1_maxt2 select 0  as time, south_north, west_east, max(t2) as maxt2 from wrfout_d02_2016_07_01_00_00_00_t2 group by south_north, west_east; create table if not exists wrfout_d02_p2_maxt2 as select 0  as time, south_north, west_east, max(t2) as maxt2 from wrfout_d02_2016_07_05_00_00_00_t2 group by south_north, west_east; insert overwrite table wrfout_d02_p2_maxt2 select 0  as time, south_north, west_east, max(t2) as maxt2 from wrfout_d02_2016_07_05_00_00_00_t2 group by south_north, west_east; create table if not exists wrfout_d02_p1_maxt2_n like wrfout_d02_2016_07_01_00_00_00_t2; insert overwrite table wrfout_d02_p1_maxt2_n select wrfout_d02_2016_07_01_00_00_00_t2.row_no, wrfout_d02_p1_maxt2.* from wrfout_d02_p1_maxt2 join wrfout_d02_2016_07_01_00_00_00_t2 on (wrfout_d02_p1_maxt2.time = wrfout_d02_2016_07_01_00_00_00_t2.time  and wrfout_d02_p1_maxt2.south_north = wrfout_d02_2016_07_01_00_00_00_t2.south_north and wrfout_d02_p1_maxt2.west_east = wrfout_d02_2016_07_01_00_00_00_t2.west_east); create table if not exists wrfout_d02_p2_maxt2_n like wrfout_d02_2016_07_01_00_00_00_t2; insert overwrite table wrfout_d02_p2_maxt2_n select wrfout_d02_2016_07_05_00_00_00_t2.row_no, wrfout_d02_p2_maxt2.* from wrfout_d02_p2_maxt2 join wrfout_d02_2016_07_05_00_00_00_t2 on (wrfout_d02_p2_maxt2.time = wrfout_d02_2016_07_05_00_00_00_t2.time  and wrfout_d02_p2_maxt2.south_north = wrfout_d02_2016_07_05_00_00_00_t2.south_north and wrfout_d02_p2_maxt2.west_east = wrfout_d02_2016_07_05_00_00_00_t2.west_east)"

hive-query-max-diff-t2:: hive-query-max-diff-t2-fill
	docker  exec -i hive beeline -u jdbc:hive2://localhost:10000 -e "create table if not exists wrfout_d02_maxt2_diff like wrfout_d02_2016_07_01_00_00_00_t2; insert overwrite table wrfout_d02_maxt2_diff select (wrfout_d02_p2_maxt2_n.t2 - wrfout_d02_p1_maxt2_n.t2) as t2 from wrfout_d02_p2_maxt2_n, wrfout_d02_p1_maxt2_n where wrfout_d02_p1_maxt2_n.row_no = wrfout_d02_p2_maxt2_n.row_no"



hive-hangout-query-max::
	docker  exec -i hive beeline -u jdbc:hive2://localhost:10000 -e "select wrfout_d02_2016_07_01_00_00_00_t2.t2 - wrfout_d02_2016_07_05_00_00_00_t2.t2 as maxt2 from wrfout_d02_2016_07_01_00_00_00_t2, wrfout_d02_2016_07_05_00_00_00_t2 where wrfout_d02_2016_07_05_00_00_00_t2.row_no = wrfout_d02_2016_07_01_00_00_00_t2.row_no";

hive-hangout-query-min::
	t2res=`docker  exec -i hive beeline -u jdbc:hive2://localhost:10000 -e "select min(wrfout_d02_2016_07_01_00_00_00_t2.t2 - wrfout_d02_2016_07_05_00_00_00_t2.t2) as mint2 from wrfout_d02_2016_07_01_00_00_00_t2, wrfout_d02_2016_07_05_00_00_00_t2 where wrfout_d02_2016_07_05_00_00_00_t2.row_no = wrfout_d02_2016_07_01_00_00_00_t2.row_no"`;echo $$t2res | grep mint2;


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
