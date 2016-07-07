#Conf target and scripts
DOCKER=$(shell which docker)
DATASET=somedataset
PROV_ID=someprovid

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
