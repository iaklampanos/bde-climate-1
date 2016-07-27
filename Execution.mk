# Configuration (docker) targets and scripts
SHELL=/bin/bash
CUSER=$(shell whoami)
REG=d01
RSTARTDT=20070103
RDURATION=6
USERNAM=bde2020
MODELSRV=tornado.ipta.demokritos.gr
LOGS_DIR=/mnt/share500/logs/

help::
	#help goes here###
	echo "help goes here";


run-wrf-background::
	if [ -f /mnt/share500/logs/$(CUSER).wrf.log ];then\
	  wrfstatus=`cat /mnt/share500/logs/$(CUSER).wrf.log | grep "__FINISHED_WRF__"`;\
	  if [ "$$wrfstatus" = "" ];then\
	    echo "WRF RUNNING JOB ALREADY";\
	  else\
	    cat /mnt/share500/logs/$(CUSER).wrf.log >> /mnt/share500/logs/$(CUSER).log;\
	    nohup sh -c "echo __STARTED_WRF__; make -s run-wrf RSTARTDT=$(RSTARTDT) RDURATION=$(RDURATION) REG=$(REG) CUSER=$(CUSER); echo __FINISHED_WRF__; | tee /mnt/share500/logs/$(CUSER).wrf.log" &;\
	    echo $! > $(CUSER)_curr.wrf.pid;\
	  fi;\
	else\
	  nohup sh -c "echo __STARTED_WRF__; make -s run-wrf RSTARTDT=$(RSTARTDT) RDURATION=$(RDURATION) REG=$(REG) CUSER=$(CUSER); echo __FINISHED_WRF__; | tee /mnt/share500/logs/$(CUSER).wrf.log" &;\
	  echo $! > $(CUSER)_curr.wrf.pid;\
	fi; 
	


run-wps::
	### Run WPS  ###
	#usage run-wps RSTARTDT=StartDateOfModel RDURATION=DurationOfModelInHoursi REG<d01|d02>
	d01=0;d02=0;d03=0;reg=$(REG);\
	if [ "$(REG)" = "d01" ]; then d01=1; fi;\
	if [ "$(REG)" = "d02" ]; then d02=1; fi;\
	if [ "$(REG)" = "d03" ]; then d03=1; fi;\
	CURRUUID=`cat $(CUSER)_curr.UUID`;\
	echo "Progress: Starting WPS Process at time=|`date`| with REG=|$(REG)| CUSER=|$(CUSER)| RDURATION=|$(RDURATION)| RSTARTDT=|$(RSTARTDT)| RUN_ID=|$$CURRUUID|";\
	if make -f sc5_query.mk PROV_SEL_ \
	  TYPE=wps REG=$(REG) CUSER=$(CUSER) RDURATION=$(RDURATION) RSTARTDT=$(RSTARTDT) &> $(LOGS_DIR)cql_log; then\
	  CRES=`make -f sc5_query.mk PROV_SEL_ \
	  TYPE=wps REG=$(REG) CUSER=$(CUSER) RDURATION=$(RDURATION) RSTARTDT=$(RSTARTDT) | tail -n1 | grep 1`;\
	else\
	  echo "Progress: Error in CQL command, check $(LOGS_DIR)cql_log file";\
	  exit 1;\
	fi;\
	if [ "$$CRES" = "" ];then\
	  CUUID=`uuidgen`;\
	  if make -f sc5_query.mk PROV_INS_ TYPE=wps PWRFID=null BPWRFID=null\
	     REG=$(REG) CUUID=$$CUUID CUSER=$(CUSER) RDURATION=$(RDURATION) RSTARTDT=$(RSTARTDT) &> $(LOGS_DIR)cql_log; then\
	    echo "Progress: All OK from Cassandra to Start WPS Process";\
	  else\
	    echo "Progress: Error in CQL command, check $(LOGS_DIR)cql_log file";\
	    exit 1;\
	  fi;\
	  echo "Progress: Start of [Remote] ]WPS session on WRF Server";\
	  ssh $(USERNAM)@$(MODELSRV) "cd $$CURRUUID/Run/bin && "\
	  "./prepare.sh $(RSTARTDT) 1 0 $$d01 $$d02 $$d03 "\
	  "$(RDURATION) $(RDURATION) $(RDURATION) 0 0 0 && "\
	  "sed -i '13s|bde2020user1|$$CURRUUID|' fws.sh && nohup ./fws.sh && "\
	  "cd .. && echo done;";\
	  echo "Progress: End of [Remote] WPS session on WRF Server";\
	  tmpdirwps=`mktemp -d`;\
	  echo "Progress: Copying WPS files from [Remote] WRF Server";\
	  scp $(USERNAM)@$(MODELSRV):~/$$CURRUUID/Run/WPS/RunData/met_em.$(REG)* $$tmpdirwps &&\
	  echo "Progress: Copying WPS files from [Remote] WRF Server OK!";\
	  ipaths="";\
	  for f in $$tmpdirwps/met_em.$(REG)*; do \
	    ncrename -O -d z-dimension0003,z_dimension0003 $$f $$f;\
	    ncrename -O -d z-dimension0012,z_dimension0012 $$f $$f;\
	    ncrename -O -d z-dimension0016,z_dimension0016 $$f $$f;\
	    ncrename -O -d z-dimension0024,z_dimension0024 $$f $$f;\
	    start=`date +%s`;\
	    make  $(MAKEOPTS) ingest-file NETCDFFILE=$$f ;\
	    end=`date +%s`;\
            echo "Progress: ingestion took: "$$((end-start))" seconds";\
	    ipaths="'"`basename $$f`"',"$$ipaths;\
	  done;ipaths=`echo $${ipaths::-1}`;\
	  rm -rf $$tmpdirwps &&\
	  ALISTI=`make -f sc5_query.mk PROV_OPER_DOWN_ CUUID=$$CUUID OPER=select`;\
	  make -f sc5_query.mk PROV_OPER_DOWN_ CUUID=$$CUUID OPER=delete &&\
	  ALISTI=`echo $$ALISTI|sed 's|.*\[||;s|].*||;s|000+0000||g;s|issuccessful: False|issuccessful: True|' `;\
	  ALISTI=`echo $$ALISTI| sed "s|et: '\([^']*\)'|et:toTimestamp(now())|"`;\
	  AL=`echo $$ALISTI |sed 's|(|_pb_|g;s|)|_pe_|g'`;\
	  make -f sc5_query.mk PROV_UPD_ \
	  ipaths="\"$$ipaths\"" CUUID=$$CUUID ALISTI="\"$$AL\"" &> $(LOGS_DIR)cql_log &&\
	  echo "PROV_ID_WPS_ "$$CUUID;\
	  else\
	    CPAR=`make -s -f sc5_query.mk PROV_SEL_ \
	    TYPE=wps REG=$(REG) CUSER=$(CUSER) RDURATION=$(RDURATION) RSTARTDT=$(RSTARTDT) | tail -n3 |head -n1 |sed 's| ||g'`;\
	    echo "PROV_ID_WPS_ "$$CPAR;\
	    nclist=`/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "select paths from testprov.prov where id=$$CPAR" | head -n4 | tail -n1 | tr -d "',{,}"|sed 's|\r||g'` ;\
	  tmpdirwps=`mktemp -d`;\
	  for ncf in $$nclist; do\
	    echo $$ncf;\
	    ncfo=$$tmpdirwps"/"$$ncf;\
	    start=`date +%s`;\
	    make $(MAKEOPTS) export-file NETCDFKEY=$$ncf NETCDFOUT=$$ncfo;\
	    end=`date +%s`;\
            echo "Progress: export took: "$$((end-start))" seconds";\
	    ncrename -O -d .z_dimension0003,z-dimension0003 $$ncfo $$ncfo;\
	    ncrename -O -d .z_dimension0012,z-dimension0012 $$ncfo $$ncfo;\
	    ncrename -O -d .z_dimension0016,z-dimension0016 $$ncfo $$ncfo;\
	    ncrename -O -d .z_dimension0024,z-dimension0024 $$ncfo $$ncfo;\
	  done;\
	  ssh $(USERNAM)@$(MODELSRV) "cd $$CURRUUID/Run/WPS/ ; if [ ! -d RunData ]; then cp -r RunData_init RunData; mkdir -p RunData/met2; mkdir -p RunData/met3; fi;" &&\
	  echo "Progress: Copying WPS files to [Remote] WRF Server";\
	  scp $$tmpdirwps/met_em.$(REG)* $(USERNAM)@$(MODELSRV):~/$$CURRUUID/Run/WPS/RunData/ &&\
	  echo "Progress: Copying WPS files to [Remote] WRF Server OK!";\
	  rm -rf $$tmpdirwps;\
	fi;\
	make $(MAKEOPTS) run-ssh-cp;\
	echo "Progress: Ended WPS Process at time=|`date`| with REG=|$(REG)| CUSER=|$(CUSER)| RDURATION=|$(RDURATION)| RSTARTDT=|$(RSTARTDT)| RUN_ID=|$$CURRUUID|";


run-wrf::
	d01=0; d02=0; d03=0; reg=$(REG);\
	if [ "$(REG)" = "d01" ]; then d01=1; fi;\
	if [ "$(REG)" = "d02" ]; then d02=1; fi;\
	if [ "$(REG)" = "d03" ]; then d03=1; fi;\
	CURRUUID=`cat $(CUSER)_curr.UUID`;\
	echo "Progress: Starting WRF Process at time=|`date`| with REG=|$(REG)| CUSER=|$(CUSER)| RDURATION=|$(RDURATION)| RSTARTDT=|$(RSTARTDT)| RUN_ID=|$$CURRUUID|";\
	start=`date +%s`;\
	make $(MAKEOPTS) -s run-wps REG=$(REG) CUSER=$(CUSER) RDURATION=$(RDURATION) RSTARTDT=$(RSTARTDT) | tee $(LOGS_DIR)$$CURRUUID"_log" &&\
	end=`date +%s`;\
	echo "Progress: WPS RUN took: "$$((end-start))" seconds";\
	PF=`cat $(LOGS_DIR)$$CURRUUID"_log" | grep "PROV_ID_WPS_"`;\
	PFI=`echo $$PF | awk -F " " '{print $$2}'`;\
	if make -f sc5_query.mk PROV_SEL_ TYPE=wrf \
	  REG=$(REG) CUSER=$(CUSER) RDURATION=$(RDURATION) RSTARTDT=$(RSTARTDT) &> $(LOGS_DIR)cql_log; then\
	  CRES=`make -f sc5_query.mk PROV_SEL_ \
	  TYPE=wrf REG=$(REG) CUSER=$(CUSER) RDURATION=$(RDURATION) RSTARTDT=$(RSTARTDT) | tail -n1 | grep 1`;\
	else\
	  echo "Progress: Error in CQL command, check $(LOGS_DIR)cql_log file";\
	  exit 1;\
	fi;\
	if [ "$$CRES" = "" ];then\
	  CUUID=`uuidgen`;\
	  if make -f sc5_query.mk PROV_INS_ TYPE=wrf BPWRFID=$$PFI PWRFID=null\
	    CUUID=$$CUUID REG=$(REG) CUSER=$(CUSER) RDURATION=$(RDURATION) RSTARTDT=$(RSTARTDT) &> $(LOGS_DIR)cql_log; then\
	    echo "Progress: All OK from Cassandra to Start WRF Process";\
	  else\
	    echo "Progress: Error in CQL command, check $(LOGS_DIR)cql_log file";\
	    exit 1;\
	  fi;\
	  echo "Progress: Start of [Remote] ]WRF session on WRF Server";\
	  ssh $(USERNAM)@$(MODELSRV) "cd $$CURRUUID/Run/bin && "\
	  "./prepare.sh $(RSTARTDT) 0 1 $$d01 $$d02 $$d03 "\
	  "$(RDURATION) $(RDURATION) $(RDURATION) 0 0 0 && "\
	  "sed -i '13s|bde2020user1|$$CURRUUID|' fws.sh && nohup ./fws.sh && "\
	  "cd .. && echo done;";\
	  echo "Progress: End of [Remote] WRF session on WRF Server";\
	  tmpdirwrf=`mktemp -d`;\
	  echo "Progress: Copying WRF files from [Remote] WRF Server";\
	  scp $(USERNAM)@$(MODELSRV):~/$$CURRUUID/Run/WRF/run_$${reg^^}/wrfout_d01* $$tmpdirwrf/;\
	  echo "Progress: Copying WPS files from [Remote] WRF Server OK!";\
	  ipaths="";\
	  for f in $$tmpdirwrf/wrfout_d01*; do \
	    ftc=`echo $$f | sed 's|d01|$(REG)|g'`;\
	    mv $$f $$ftc;\
	    start=`date +%s`;\
	    make $(MAKEOPTS) ingest-file NETCDFFILE=$$ftc NETCDF_DATA_DIR=$$tmpdirwrf;\
	    end=`date +%s`;\
	    echo "Progress: WRF ingestion took: "$$((end-start))" seconds";\
	    ipaths="'"`basename $$ftc`"',"$$ipaths;\
	  done;ipaths=`echo $${ipaths::-1}`;\
	  rm -rf $$tmpdirwrf &&\
	  ALISTI=`make -f sc5_query.mk PROV_OPER_DOWN_ CUUID=$$CUUID OPER=select`;\
	  make -f sc5_query.mk PROV_OPER_DOWN_ CUUID=$$CUUID OPER=delete &&\
	  ALISTI=`echo $$ALISTI|sed 's|.*\[||;s|].*||;s|000+0000||g;s|issuccessful: False|issuccessful: True|' `;\
	  ALISTI=`echo $$ALISTI| sed "s|et: '\([^']*\)'|et:toTimestamp(now())|"`;\
	  AL=`echo $$ALISTI |sed 's|(|_pb_|g;s|)|_pe_|g'`;echo "$$AL";\
	  make -f sc5_query.mk PROV_UPD_ \
	  ipaths="\"$$ipaths\"" CUUID=$$CUUID ALISTI="\"$$AL\"" &> $(LOGS_DIR)cql_log &&\
	  echo "PROV_ID_WRF_ "$$CUUID;\
	else\
	  CPAR=`make -s -f sc5_query.mk PROV_SEL_ \
	  TYPE=wrf REG=$(REG) CUSER=$(CUSER) RDURATION=$(RDURATION) RSTARTDT=$(RSTARTDT) | tail -n3 |head -n1 |sed 's| ||g'`;\
	  echo "PROV_ID_WRF_ "$$CPAR;\
	  nclist=`/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "select paths from testprov.prov where id=$$CPAR" | head -n4 | tail -n1 | tr -d "',{,}"|sed 's|\r||g'` ;\
	  tmpdirwrf=`mktemp -d`;\
	  for ncf in $$nclist; do\
	    echo $$ncf;\
	    ncfo=$$tmpdirwrf"/"$$ncf;\
	    start=`date +%s`;\
	    make $(MAKEOPTS) export-file NETCDFKEY=$$ncf NETCDFOUT=$$ncfo;\
	    end=`date +%s`;\
	    echo "Progress: WRF export took: "$$((end-start))" seconds";\
	  done;\
	  ssh $(USERNAM)@$(MODELSRV) "cd $$CURRUUID/Run/WRF/ && if [ ! -d run_$${reg^^} ]; then echo 'run_$${reg^^} does not exist!'; cp -r run_init_$${reg^^} run_$${reg^^};fi;";\
	  echo "Progress: Copying WRF files to [Remote] WRF Server";\
	  scp $$tmpdirwrf/wrfout_$(REG)* $(USERNAM)@$(MODELSRV):~/$$CURRUUID/Run/WRF/run_$${reg^^}/ &&\
	  echo "Progress: Copying WRF files to [Remote] WRF Server OK!";\
	  rm -rf $$tmpdirwrf;\
	fi;\
	echo "Progress: Ended WRF Process at time=|`date`| with REG=|$(REG)| CUSER=|$(CUSER)| RDURATION=|$(RDURATION)| RSTARTDT=|$(RSTARTDT)| RUN_ID=|$$CURRUUID|";



run-ssh-cp::
	CURRUUID=`cat $(CUSER)_curr.UUID`;\
	if [ "$(REG)" = "d02" ]; then\
	   ssh $(USERNAM)@$(MODELSRV) "cd $$CURRUUID/Run/WPS/RunData; cp met_em.$(REG)* met2/ ; cd met2/; rename $(REG) d01 met*";\
	fi;\
	if [ "$(REG)" = "d03" ]; then\
	   ssh $(USERNAM)@$(MODELSRV) "cd $$CURRUUID/Run/WPS/RunData; cp met_em.$(REG)* met3/ ; cd met3/; rename $(REG) d01 met*";\
	fi;



run-wrf-nest::
	### Run WRF NESTDOWN ###
	#usage run-wrf-nest RSTARTDT=StartDateOfModel RDURATION=DurationOfModelInHours REG=<d01d02|d02d03>
	d01=0; d02=0; d03=0; reg=$(REG);\
	CURRUUID=`cat $(CUSER)_curr.UUID`;\
	echo "Progress: Starting WRF NESTDOWN Process at time=|`date`| with REG=|$(REG)| CUSER=|$(CUSER)| RDURATION=|$(RDURATION)| RSTARTDT=|$(RSTARTDT)| RUN_ID=|$$CURRUUID|";\
	if [ "$(REG)" = d01d02 ];then \
	  d02=12;\
	  reg=d01;\
	  start=`date +%s`;\
	  make $(MAKEOPTS) -s run-wrf REG=$$reg CUSER=$(CUSER) RDURATION=$(RDURATION) RSTARTDT=$(RSTARTDT) | tee $(LOGS_DIR)$$CURRUUID"_log" &&\
	  end=`date +%s`;\
	  echo "Progress: WRF Process took: "$$((end-start))" seconds";\
	  PFWRF=`cat $(LOGS_DIR)$$CURRUUID"_log" | grep "PROV_ID_WRF_"`;\
	  reg=d02;\
	  start=`date +%s`;\
	  make $(MAKEOPTS) -s run-wps REG=$$reg CUSER=$(CUSER) RDURATION=$(RDURATION) RSTARTDT=$(RSTARTDT) | tee $(LOGS_DIR)$$CURRUUID"_log" &&\
	  end=`date +%s`;\
	  echo "Progress: WPS Process took: "$$((end-start))" seconds";\
	  PFWPS=`cat $(LOGS_DIR)$$CURRUUID"_log" | grep "PROV_ID_WPS_"`;\
	  PFWRFI=`echo $$PFWRF | awk -F " " '{print $$2}'`;\
	  PFWPSI=`echo $$PFWPS | awk -F " " '{print $$2}'`;\
	fi;\
	if [ "$(REG)" = d02d03 ];then \
	  d03=12;\
	  reg=d02;\
	  start=`date +%s`;\
	  make $(MAKEOPTS) -s run-wrf REG=$$reg CUSER=$(CUSER) RDURATION=$(RDURATION) RSTARTDT=$(RSTARTDT) | tee $(LOGS_DIR)$$CURRUUID"_log" &&\
	  end=`date +%s`;\
	  echo "Progress: WRF Process took: "$$((end-start))" seconds";\
	  PFWRF=`cat $(LOGS_DIR)$$CURRUUID"_log" | grep "PROV_ID_WRF_"`;\
	  reg=d03;\
	  start=`date +%s`;\
	  make $(MAKEOPTS) -s run-wps REG=$$reg CUSER=$(CUSER) RDURATION=$(RDURATION) RSTARTDT=$(RSTARTDT) | tee $(LOGS_DIR)$$CURRUUID"_log" &&\
	  end=`date +%s`;\
	  echo "Progress: WPS Process took: "$$((end-start))" seconds";\
	  PFWPS=`cat $(LOGS_DIR)$$CURRUUID"_log" | grep "PROV_ID_WPS_"`;\
	  PFWRFI=`echo $$PFWRF | awk -F " " '{print $$2}'`;\
	  PFWPSI=`echo $$PFWPS | awk -F " " '{print $$2}'`;\
	fi;\
	if make -f sc5_query.mk PROV_SEL_NEST_ REG=$(REG) PWRFID=$$PFWRFI BPWRFID=$$PFWPSI \
	  CUSER=$(CUSER) RDURATION=$(RDURATION) RSTARTDT=$(RSTARTDT) &> $(LOGS_DIR)cql_log; then\
	  CRES=`make -f sc5_query.mk PROV_SEL_NEST_ REG=$(REG) PWRFID=$$PFWRFI BPWRFID=$$PFWPSI CUSER=$(CUSER) RDURATION=$(RDURATION) RSTARTDT=$(RSTARTDT)| tail -n1 | grep 1`;\
	else\
	  echo "Progress: Error in CQL command, check cql_log file";\
	  exit 1;\
	fi;\
	if [ "$$CRES" = "" ]; then \
	  CUUID=`uuidgen`; echo $$CUUID;\
	  make -f sc5_query.mk PROV_INS_NEST_ REG=$(REG) PWRFID=$$PFWRFI BPWRFID=$$PFWPSI CUUID=$$CUUID CUSER=$(CUSER) RDURATION=$(RDURATION) RSTARTDT=$(RSTARTDT) && \
	  echo "Progress: Starting remote WRF nest down";\
	  ssh $(USERNAM)@$(MODELSRV) "cd $$CURRUUID/Run/bin && ./prepare.sh $(RSTARTDT) 0 1 $$d01 $$d02 $$d03 $(RDURATION) $(RDURATION) $(RDURATION) 0 0 0 && sed -i '13s|bde2020user1|$$CURRUUID|' fws.sh && nohup ./fws.sh && cd .. && echo done;";\
	   tmpdirwrf=`mktemp -d`;\
	   scp $(USERNAM)@$(MODELSRV):~/$$CURRUUID/Run/WRF/run_$${reg^^}/wrfout_d01* $$tmpdirwrf/;\
	   ipaths="";\
	   for f in $$tmpdirwrf/wrfout_d01*; do \
	     ftc=`echo $$f | sed 's|d01|$(REG)|g'`;\
	     mv $$f $$ftc;\
	     start=`date +%s`;\
	     make $(MAKEOPTS) ingest-file NETCDFFILE=$$ftc NETCDF_DATA_DIR=$$tmpdirwrf;\
	     end=`date +%s`;\
	     echo "Progress: WRF Ingestion took: "$$((end-start))" seconds";\
	    ipaths="'"`basename $$ftc`"',"$$ipaths;\
	   done;ipaths=`echo $${ipaths::-1}`;\
	  rm -rf $$tmpdirwrf &&\
	  ALISTI=`make -f sc5_query.mk PROV_OPER_DOWN_ CUUID=$$CUUID OPER=select`;\
	  make -f sc5_query.mk PROV_OPER_DOWN_ CUUID=$$CUUID OPER=delete &&\
	  ALISTI=`echo $$ALISTI|sed 's|.*\[||;s|].*||;s|000+0000||g;s|issuccessful: False|issuccessful: True|' `;\
	  ALISTI=`echo $$ALISTI| sed "s|et: '\([^']*\)'|et:toTimestamp(now())|"`;\
	  AL=`echo $$ALISTI |sed 's|(|_pb_|g;s|)|_pe_|g'`;echo "$$AL";\
	  make -f sc5_query.mk PROV_UPD_ ipaths="\"$$ipaths\"" CUUID=$$CUUID ALISTI="\"$$AL\"" &> cql_log &&\
	  echo "PROV_ID_WRF_ "$$CUUID;\
	else\
	  CPAR=`make -f sc5_query.mk PROV_SEL_NEST_ REG=$(REG) PWRFID=$$PFWRFI BPWRFID=$$PFWPSI CUSER=$(CUSER) RDURATION=$(RDURATION) RSTARTDT=$(RSTARTDT)|tail -n3 |head -n1|sed 's| ||g'`;\
	  echo "PROV_ID_WRF_ "$$CPAR;\
	  nclist=`/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "select paths from testprov.prov where id=$$CPAR" | head -n4 | tail -n1 | sed "s|[\{,\},\','\r']||g"`;\
	  tmpdirwrf=`mktemp -d`;\
	  for ncf in $$nclist; do\
	    echo $$ncf;\
	    ncfo=$$tmpdirwrf"/"$$ncf;\
	    start=`date +%s`;\
	    make $(MAKEOPTS) export-file NETCDFKEY=$$ncf NETCDFOUT=$$ncfo;\
	    end=`date +%s`;\
	    echo "Progress: WRF Export took: "$$((end-start))" seconds";\
	    ftc=`echo $$ncfo | sed 's|$(REG)|d01|g'`;\
	    mv $$ncfo $$ftc;\
	  done;\
	  ssh $(USERNAM)@$(MODELSRV) "cd $$CURRUUID/Run/WRF/ && if [ ! -d run_$${reg^^} ]; then echo 'run_$${reg^^} does not exist!'; cp -r run_init_$${reg^^} run_$${reg^^};fi;";\
	  echo "Progress: Copying WRF files to [Remote] WRF Server";\
	  scp $$tmpdirwrf/wrfout_d01* $(USERNAM)@$(MODELSRV):~/$$CURRUUID/Run/WRF/run_$${reg^^}/ &&\
	  echo "Progress: Copying WRF files to [Remote] WRF Server OK!";\
	  rm -rf $$tmpdirwrf;\
	fi;
	echo "Progress: Ended WRF NESTDOWN Process at time=|`date`| with REG=|$(REG)| CUSER=|$(CUSER)| RDURATION=|$(RDURATION)| RSTARTDT=|$(RSTARTDT)| RUN_ID=|$$CURRUUID|";


run-wrf-deprec::
	d01=0; d02=0; d03=0; reg=$(REG);\
	if [ "$(REG)" = d01 ]; then d01=1; fi;\
	if [ "$(REG)" = d02 ]; then d02=1; fi;\
	if [ "$(REG)" = d03 ]; then d03=1; fi;\
	CURRUUID=`cat $(CUSER)_curr.UUID`;\
	PF=`make $(MAKEOPTS) -s run-wps | grep "PROV_ID_WPS_"`;\
	PFI=`echo $$PF | awk -F " " '{print $$2}'`;\
	CRES=`/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e " select id from testprov.prov where bparentid=$$PFI and isvalid=True and user='$$CURRUUID' and paramset contains 'wrf:1' and paramset contains 'sst:$(RSTARTDT)' and paramset contains 'd01:$$d01' and paramset contains 'd02:$$d02' and paramset contains 'd03:$$d03' and paramset contains 'd01rd:$(RDURATION)' and paramset contains 'd02rd:$(RDURATION)' and paramset contains 'd03rd:$(RDURATION)' and paramset contains 'd01k:$$d01' and paramset contains 'd02k:$$d02' and paramset contains 'd03k:$$d03' limit 1 allow filtering"  2>/dev/null | tail -n1| grep 1`;\
	echo "the grep result " $$CRES;\
	if [ "$$CRES" = "" ];then \
	  CUUID=`uuidgen`;\
	  /usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "INSERT INTO testprov.prov (id, user, isvalid, bparentid, paths, paramset, type, downscaling, createdat, lasteditedat) VALUES ($$CUUID, '$$CURRUUID', False, $$PFI, {'/home/bde2020/data/BINARY/'}, {'sst:$(RSTARTDT)','wps:0','wrf:1','d01:$$d01','d02:$$d02','d03:$$d03','d01rd:$(RDURATION)','d02rd:$(RDURATION)','d03rd:$(RDURATION)','d01k:$$d01','d02k:$$d02','d03k:$$d03'}, 'wrf',[{agentname: 'wrf', agenttype:'software', agentversion:'0.0.1', st:toTimestamp(now()), et:toTimestamp(now()), params:{'d01':'$$d01','d02':'$$d02','d03':'$$d03'}, issuccessful:False}], toTimestamp(now()), toTimestamp(now()))";\
	  echo "Progress: Starting remote WRF";\
	  ssh $(USERNAM)@$(MODELSRV) "cd $$CURRUUID/Run/bin && "\
	  "./prepare.sh $(RSTARTDT) 0 1 $$d01 $$d02 $$d03 $(RDURATION) $(RDURATION) $(RDURATION) 0 0 0 &&"\
	  " sed -i '13s|bde2020user1|$$CURRUUID|' fws.sh && nohup ./fws.sh && cd .. && echo done;";\
	  tmpdirwrf=`mktemp -d`;\
	  scp $(USERNAM)@$(MODELSRV):~/$$CURRUUID/Run/WRF/run_$${reg^^}/wrfout_d01* $$tmpdirwrf/;\
	  ipaths="";\
	  for f in $$tmpdirwrf/wrfout_d01*; do \
	    ftc=`echo $$f | sed 's|d01|$(REG)|g'`;\
	    mv $$f $$ftc;\
	    make $(MAKEOPTS) ingest-file NETCDFFILE=$$ftc NETCDF_DATA_DIR=$$tmpdirwrf;\
	    ipaths="'"`basename $$ftc`"' "$$ipaths;\
	  done;\
	  ALISTI=`/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "select downscaling from testprov.prov where id=$$CUUID;"`;\
	  /usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "delete downscaling from testprov.prov where id=$$CUUID";\
	  ALISTI=`echo $$ALISTI|sed 's|.*\[||;s|].*||;s|000+0000||g;s|issuccessful: False|issuccessful: True|' `;\
	  ALISTI=`echo $$ALISTI| sed "s|et: '\([^']*\)'|et:toTimestamp(now())|"`;\
	  rm -rf $$tmpdirwrf;\
	  /usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "UPDATE testprov.prov set isvalid=True, paths={$$ipaths}, lasteditedat=toTimestamp(now()),downscaling=[$$ALISTI] +downscaling WHERE id=$$CUUID";\
	  echo "PROV_ID_WRF_ "$$CUUID;\
	else\
	  CPAR=`/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e " select id from testprov.prov where isvalid=True and user='$$CURRUUID' and paramset contains 'wrf:1' and paramset contains 'sst:$(RSTARTDT)' and paramset contains 'd01:$$d01' and paramset contains 'd02:$$d02' and paramset contains 'd03:$$d03' and paramset contains 'd01rd:$(RDURATION)' and paramset contains 'd02rd:$(RDURATION)' and paramset contains 'd03rd:$(RDURATION)' and paramset contains 'd01k:$$d01' and paramset contains 'd02k:$$d02' and paramset contains 'd03k:$$d03' limit 1 allow filtering"|tail -n3 |head -n1|sed 's| ||g'`;\
	  echo "PROV_ID_WRF_ "$$CPAR;\
	  nclist=`/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "select paths from testprov.prov where id=$$CPAR" | head -n4 | tail -n1 | sed "s|[\{,\},\','\r']||g"`;echo $$nclist;\
	  for ncf in $$nclist; do \
	    echo $$ncf;\
	    make $(MAKEOPTS) export-file NETCDFKEY=$$ncf NETCDFOUT=$$ncf;\
	  done;\
	  ssh $(USERNAM)@$(MODELSRV) "cd $$CURRUUID/Run/WRF/ && if [ ! -d run_$${reg^^} ]; then echo 'run_$${reg^^} does not exist!'; cp -r run_init_$${reg^^} run_$${reg^^};fi;";\
	  scp ./wrfout_$(REG)* $(USERNAM)@$(MODELSRV):~/$$CURRUUID/Run/WRF/run_$${reg^^}/;\
	  rm -f ./wrfout_*;\
	fi;



run-wps-deprec::
	### Run WPS  ###
	#usage run-wps RSTARTDT=StartDateOfModel RDURATION=DurationOfModelInHours
	d01=0;d02=0;d03=0;reg=$(REG);\
	if [ "$(REG)" = "d01" ]; then d01=1; fi;\
	if [ "$(REG)" = "d02" ]; then d02=1; fi;\
	if [ "$(REG)" = "d03" ]; then d03=1; fi;\
	CURRUUID=`cat $(CUSER)_curr.UUID`;\
	QUERYC="select id from testprov.prov where "\
	" isvalid=True and user='$$CURRUUID' and paramset contains 'wps:1' and paramset contains 'sst:$(RSTARTDT)' and paramset contains 'd01:$$d01'"\
	" and paramset contains 'd02:$$d02' and paramset contains 'd03:$$d03' and paramset contains 'd01rd:$(RDURATION)' "\
	" and paramset contains 'd02rd:$(RDURATION)' and paramset contains 'd03rd:$(RDURATION)' and paramset contains 'd01k:$$d01'"\
	" and paramset contains 'd02k:$$d02' and paramset contains 'd03k:$$d03' limit 1 allow filtering ";\
	CRES=`/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "$$QUERYC" 2>/dev/null | tail -n1| grep 1` ;\
	if [ "$$CRES" = "" ];then \
	  CUUID=`uuidgen`;\
	  /usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "INSERT INTO testprov.prov (id, user, isvalid, paths, paramset, type, downscaling, createdat, lasteditedat) VALUES ($$CUUID, '$$CURRUUID', False, {'/home/bde2020/data/BINARY/'}, {'sst:$(RSTARTDT)','wps:1','wrf:0','d01:$$d01','d02:$$d02','d03:$$d03','d01rd:$(RDURATION)','d02rd:$(RDURATION)','d03rd:$(RDURATION)','d01k:$$d01','d02k:$$d02','d03k:$$d03'}, 'wps',[{agentname: 'wps', agenttype:'software', agentversion:'0.0.1', st:toTimestamp(now()), et:toTimestamp(now()), params:{'d01':'$$d01','d02':'$$d02','d03':'$$d03'}, issuccessful:False}], toTimestamp(now()), toTimestamp(now()))" ;\
	  echo "Progress: Starting remote WPS";\
	  ssh $(USERNAM)@$(MODELSRV) "cd $$CURRUUID/Run/bin && "\
	  "./prepare.sh $(RSTARTDT) 1 0 $$d01 $$d02 $$d03 $(RDURATION) $(RDURATION) $(RDURATION) 0 0 0 &&"\
	  " sed -i '13s|bde2020user1|$$CURRUUID|' fws.sh && nohup ./fws.sh && cd .. && echo done;";\
	  tmpdirwps=`mktemp -d`;\
	  scp $(USERNAM)@$(MODELSRV):~/$$CURRUUID/Run/WPS/RunData/met_em.$(REG)* $$tmpdirwps/ &&\
	  ipaths="";\
	  for f in $$tmpdirwps/met_em.$(REG)*; do \
	    ncrename -O -d z-dimension0003,z_dimension0003 $$f $$f;\
	    ncrename -O -d z-dimension0012,z_dimension0012 $$f $$f;\
	    ncrename -O -d z-dimension0016,z_dimension0016 $$f $$f;\
	    ncrename -O -d z-dimension0024,z_dimension0024 $$f $$f;\
	    make  $(MAKEOPTS) ingest-file NETCDFFILE=$$f ;\
	    ipaths="'"`basename $$f`"' "$$ipaths;\
	  done;\
	  ALISTI=`/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "select downscaling from testprov.prov where id=$$CUUID;"` ;\
	  /usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "delete downscaling from testprov.prov where id=$$CUUID" ;\
	  ALISTI=`echo $$ALISTI|sed 's|.*\[||;s|].*||;s|000+0000||g;s|issuccessful: False|issuccessful: True|' `;\
	  ALISTI=`echo $$ALISTI| sed "s|et: '\([^']*\)'|et:toTimestamp(now())|"`;\
	  rm -rf $$tmpdirwps;\
	  /usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "UPDATE testprov.prov set isvalid=True, paths={$$ipaths}, lasteditedat=toTimestamp(now()),downscaling=[$$ALISTI] +downscaling WHERE id=$$CUUID" ;\
	  echo "PROV_ID_WPS_ "$$CUUID;\
	else\
	  CPAR=`/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e " select id from testprov.prov where isvalid=True and user='$$CURRUUID' and paramset contains 'wps:1' and paramset contains 'sst:$(RSTARTDT)' and paramset contains 'd01:$$d01' and paramset contains 'd02:$$d02' and paramset contains 'd03:$$d03' and paramset contains 'd01rd:$(RDURATION)' and paramset contains 'd02rd:$(RDURATION)' and paramset contains 'd03rd:$(RDURATION)' and paramset contains 'd01k:$$d01' and paramset contains 'd02k:$$d02' and paramset contains 'd03k:$$d03' limit 1 allow filtering"| tail -n3 |head -n1 |sed 's| ||g'` ;\
	  echo "PROV_ID_WPS_ "$$CPAR;\
	  nclist=`/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "select paths from testprov.prov where id=$$CPAR" | head -n4 | tail -n1 | tr -d "',{,}"|sed 's|\r||g'` ;\
	  tmpdirwps=`mktemp -d`;\
	  for ncf in $$nclist; do\
	    echo $$ncf;\
	    ncfo=$$tmpdirwps"/"$$ncf;\
	    make $(MAKEOPTS) export-file NETCDFKEY=$$ncf NETCDFOUT=$$ncfo;\
	    ncrename -O -d .z_dimension0003,z-dimension0003 $$ncfo $$ncfo;\
	    ncrename -O -d .z_dimension0012,z-dimension0012 $$ncfo $$ncfo;\
	    ncrename -O -d .z_dimension0016,z-dimension0016 $$ncfo $$ncfo;\
	    ncrename -O -d .z_dimension0024,z-dimension0024 $$ncfo $$ncfo;\
	  done;\
	  ssh $(USERNAM)@$(MODELSRV) "cd $$CURRUUID/Run/WPS/ ; if [ ! -d RunData ]; then cp -r RunData_init RunData; mkdir -p RunData/met2; mkdir -p RunData/met3; fi;" &&\
	  scp $$tmpdirwps/met_em.$(REG)* $(USERNAM)@$(MODELSRV):~/$$CURRUUID/Run/WPS/RunData/ ;\
	  rm -rf $$tmpdirwps;\
	fi;\
	make $(MAKEOPTS) run-ssh-cp;
