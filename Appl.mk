#Conf target and scripts
DOCKER=$(shell which docker)
DATASET=somedataset
PROV_ID=someprovid

get-prov-tree::
	res=`$(DOCKER) exec -i bdeclimate1_cassandra_1 cqlsh -e "select id,parentid, bparentid, user, paramset, type, downscaling, createdat, lasteditedat, paths  from testprov.prov where id=$(PROV_ID) limit 1" | tail -n+4 | head -n-2`;\
	id_res=`echo $$res | awk -F '|' '{print $$1}'i | tr -d ' '`;\
	id_par=`echo $$res | awk -F '|' '{print $$2}'| tr -d ' '`;\
	id_bpar=`echo $$res | awk -F '|' '{print $$3}'| tr -d ' '`;\
	id_us=`echo $$res | awk -F '|' '{print $$4}'i | tr -d ' '`;\
	id_param=`echo $$res | awk -F '|' '{print $$5}'| tr -d ' '`;\
	id_type=`echo $$res | awk -F '|' '{print $$6}'| tr -d ' '`;\
	id_dw=`echo $$res | awk -F '|' '{print $$7}'i | tr -d ' '`;\
	id_cr=`echo $$res | awk -F '|' '{print $$8}'| tr -d ' '`;\
	id_lt=`echo $$res | awk -F '|' '{print $$9}'| tr -d ' '`;\
	id_pth=`echo $$res | awk -F '|' '{print $$10}'| tr -d ' '`;\
	echo $$id_res "," $$id_par "," $$id_bpar "," $$id_dw "," $$id_pth;


get-prov::
	echo "getting provenance for dataset" $(DATASET);\
	pi="0";\
	bi="0";\
	res=`$(DOCKER) exec -i bdeclimate1_cassandra_1 cqlsh -e "select id,parentid, bparentid, user, paramset, type, downscaling, createdat, lasteditedat, paths from testprov.prov where paths contains '$(DATASET)'  limit 1 allow filtering" | tail -n+4 | head -n-2`;\
	id_res=`echo $$res | awk -F '|' '{print $$1}'i | tr -d ' '`;\
	id_par=`echo $$res | awk -F '|' '{print $$2}'| tr -d ' '`;\
	id_bpar=`echo $$res | awk -F '|' '{print $$3}'| tr -d ' '`;\
	id_us=`echo $$res | awk -F '|' '{print $$4}'i | tr -d ' '`;\
	id_param=`echo $$res | awk -F '|' '{print $$5}'| tr -d ' '`;\
	id_type=`echo $$res | awk -F '|' '{print $$6}'| tr -d ' '`;\
	id_dw=`echo $$res | awk -F '|' '{print $$7}'i | tr -d ' '`;\
	id_cr=`echo $$res | awk -F '|' '{print $$8}'| tr -d ' '`;\
	id_lt=`echo $$res | awk -F '|' '{print $$9}'| tr -d ' '`;\
	id_pth=`echo $$res | awk -F '|' '{print $$10}'| tr -d ' '`;\
	echo $$id_res "," $$id_par "," $$id_bpar "," $$id_dw "," $$id_pth;\
	if [ "$$id_bpar" != "null" ] || [ "$$id_par" != "null" ]; then\
	  while true; do\
	    if [ "$$id_par" = "null" ]; then\
	      pi="1";\
	    else\
	      make -s get-prov-tree PROV_ID=$$id_par;\
	      id_par=`make -s get-prov-tree PROV_ID=$$id_par | awk -F ',' '{print $$2}'| sed 's| ||g'`;\
	    fi;\
	    if [ "$$id_bpar" =  "null" ]; then\
	      bi="1";\
	    else\
	      make -s get-prov-tree PROV_ID=$$id_bpar;\
	      id_bpar=`make -s get-prov-tree PROV_ID=$$id_bpar | awk -F ',' '{print $$3}'| sed 's| ||g'`;\
	    fi;\
	    echo "first  parent :"$$id_par":    second parent :"$$id_bpar":";\
	    if [ "$$id_bpar" = "null" ] && [ "$$id_par" = "null" ]; then\
	      break;\
	    fi;\
	  done;\
	fi;
