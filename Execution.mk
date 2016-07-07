# Configuration (docker) targets and scripts
SHELL=/bin/bash
CUSER=$(shell whoami)
REG=d01
RSTARTDT=20070103
RDURATION=6
USERNAM=bde2020
MODELSRV=tornado.ipta.demokritos.gr


test-cat::
	CUUID=`uuidgen`;\
	echo $(CUSER)_$$CUUID > "$(CUSER)_"curr.UUID;\
	CURRUUID=`cat $(CUSER)_curr.UUID`;echo $$CURRUUID;


run-wps::
	### Run WPS  ###
	#usage run-wps RSTARTDT=StartDateOfModel RDURATION=DurationOfModelInHours
	d01=0;d02=0;d03=0;reg=$(REG);\
	if [ "$(REG)" = "d01" ]; then d01=1; fi;\
	if [ "$(REG)" = "d02" ]; then d02=1; fi;\
	if [ "$(REG)" = "d03" ]; then d03=1; fi;\
	CURRUUID=`cat $(CUSER)_curr.UUID`;\
	CRES=`/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e " select id from testprov.prov where "\
	" isvalid=True and user='$$CURRUUID' and paramset contains 'wps:1' and paramset contains 'sst:$(RSTARTDT)' and paramset contains 'd01:$$d01'"\
	" and paramset contains 'd02:$$d02' and paramset contains 'd03:$$d03' and paramset contains 'd01rd:$(RDURATION)' "\
	" and paramset contains 'd02rd:$(RDURATION)' and paramset contains 'd03rd:$(RDURATION)' and paramset contains 'd01k:$$d01'"\
	" and paramset contains 'd02k:$$d02' and paramset contains 'd03k:$$d03' limit 1 allow filtering"| tail -n1| grep 1` ;\
	if [ "$$CRES" = "" ];then \
	  CUUID=`uuidgen`;\
	  /usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "INSERT INTO testprov.prov (id, user, isvalid, paths, paramset, type, downscaling, createdat, lasteditedat) VALUES ($$CUUID, '$$CURRUUID', False, {'/home/bde2020/data/BINARY/'}, {'sst:$(RSTARTDT)','wps:1','wrf:0','d01:$$d01','d02:$$d02','d03:$$d03','d01rd:$(RDURATION)','d02rd:$(RDURATION)','d03rd:$(RDURATION)','d01k:$$d01','d02k:$$d02','d03k:$$d03'}, 'wps',[{agentname: 'wps', agenttype:'software', agentversion:'0.0.1', st:toTimestamp(now()), et:toTimestamp(now()), params:{'d01':'$$d01','d02':'$$d02','d03':'$$d03'}, issuccessful:False}], toTimestamp(now()), toTimestamp(now()))" ;\
	  ssh $(USERNAM)@$(MODELSRV) "cd $$CURRUUID/Run/bin && "\
	  "./prepare.sh $(RSTARTDT) 1 0 $$d01 $$d02 $$d03 $(RDURATION) $(RDURATION) $(RDURATION) 0 0 0 &&"\
	  " sed -i '13s|bde2020user1|$$CURRUUID|' fws.sh && nohup ./fws.sh && cd .. && echo done;";\
	  scp $(USERNAM)@$(MODELSRV):~/$$CURRUUID/Run/WPS/RunData/met_em.$(REG)* . &&\
	  for f in met_em.$(REG)*; do \
	    ncrename -O -d z-dimension0003,z_dimension0003 $$f $$f;\
	    ncrename -O -d z-dimension0012,z_dimension0012 $$f $$f;\
	    ncrename -O -d z-dimension0016,z_dimension0016 $$f $$f;\
	    ncrename -O -d z-dimension0024,z_dimension0024 $$f $$f;\
	    make  $(MAKEOPTS) ingest-file NETCDFFILE=$$f ;\
	  done;\
	  ALISTI=`/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "select downscaling from testprov.prov where id=$$CUUID;"` ;\
	  /usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "delete downscaling from testprov.prov where id=$$CUUID" ;\
	  ALISTI=`echo $$ALISTI|sed 's|.*\[||;s|].*||;s|000+0000||g;s|issuccessful: False|issuccessful: True|' `;\
	  ALISTI=`echo $$ALISTI| sed "s|et: '\([^']*\)'|et:toTimestamp(now())|"`;\
	  ipaths=`ls -d met_em.$(REG)* | sed "s|^|'|g;s|$$|'|g"`; ipaths=`echo $$ipaths | sed 's| |,|g'`;\
	  /usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "UPDATE testprov.prov set isvalid=True, paths={$$ipaths}, lasteditedat=toTimestamp(now()),downscaling=[$$ALISTI] +downscaling WHERE id=$$CUUID" ;\
	  echo "PROV_ID_WPS_ "$$CUUID;\
	else\
	  CPAR=`/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e " select id from testprov.prov where isvalid=True and user='$$CURRUUID' and paramset contains 'wps:1' and paramset contains 'sst:$(RSTARTDT)' and paramset contains 'd01:$$d01' and paramset contains 'd02:$$d02' and paramset contains 'd03:$$d03' and paramset contains 'd01rd:$(RDURATION)' and paramset contains 'd02rd:$(RDURATION)' and paramset contains 'd03rd:$(RDURATION)' and paramset contains 'd01k:$$d01' and paramset contains 'd02k:$$d02' and paramset contains 'd03k:$$d03' limit 1 allow filtering"| tail -n3 |head -n1 |sed 's| ||g'` ;\
	  echo "PROV_ID_WPS_ "$$CPAR;\
	  nclist=`/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "select paths from testprov.prov where id=$$CPAR" | head -n4 | tail -n1 | tr -d "',{,}"|sed 's|\r||g'` ;\
	  for ncf in $$nclist; do\
	    echo $$ncf;\
	    make $(MAKEOPTS) export-file NETCDFKEY=$$ncf NETCDFOUT=$$ncf ;\
	    ncrename -O -d .z_dimension0003,z-dimension0003 $$ncf $$ncf;\
	    ncrename -O -d .z_dimension0012,z-dimension0012 $$ncf $$ncf;\
	    ncrename -O -d .z_dimension0016,z-dimension0016 $$ncf $$ncf;\
	    ncrename -O -d .z_dimension0024,z-dimension0024 $$ncf $$ncf;\
	  done;\
	  ssh $(USERNAM)@$(MODELSRV) "cd $$CURRUUID/Run/WPS/ ; if [ ! -d RunData ]; then cp -r RunData_init RunData; mkdir -p RunData/met2; mkdir -p RunData/met3; fi;" &&\
	  scp ./met_em.$(REG)* $(USERNAM)@$(MODELSRV):~/$$CURRUUID/Run/WPS/RunData/ ;\
	fi;\
	make $(MAKEOPTS) run-ssh-cp;\
	rm -f ./met_em.*;


run-ssh-cp::
	if [ "$(REG)" = "d02" ]; then\
	   ssh $(USERNAM)@$(MODELSRV) "cd $$CURRUUID/Run/WPS/RunData; for ft in met_em.$(REG)*; do ftc=`echo $$ft | sed 's|$(REG)|d01|g'`; cp $$ft met2/$$ftc; done;";\
	fi;\
	if [ "$(REG)" = "d03" ]; then\
	   ssh $(USERNAM)@$(MODELSRV) "cd $$CURRUUID/Run/WPS/RunData; for ft in met_em.$(REG)*; do ftc=`echo $$ft | sed 's|$(REG)|d01|g'`; cp $$ft met3/$$ftc; done;";\
	fi;

run-wps-no-export-copy::
	d01=0;d02=0;d03=0;reg=$(REG);\
	if [ "$(REG)" = "d01" ]; then d01=1; fi;\
	if [ "$(REG)" = "d02" ]; then d02=1; fi;\
	if [ "$(REG)" = "d03" ]; then d03=1; fi;\
	CURRUUID=`cat $(CUSER)_curr.UUID`;\
	CRES=`/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e " select id from testprov.prov where "\
	" isvalid=True and user='$$CURRUUID' and paramset contains 'wps:1' and paramset contains 'sst:$(RSTARTDT)' and paramset contains 'd01:$$d01'"\
	" and paramset contains 'd02:$$d02' and paramset contains 'd03:$$d03' and paramset contains 'd01rd:$(RDURATION)' "\
	" and paramset contains 'd02rd:$(RDURATION)' and paramset contains 'd03rd:$(RDURATION)' and paramset contains 'd01k:$$d01'"\
	" and paramset contains 'd02k:$$d02' and paramset contains 'd03k:$$d03' limit 1 allow filtering"| tail -n1| grep 1` ;\
	if [ "$$CRES" = "" ];then \
	  CUUID=`uuidgen`;\
	  /usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "INSERT INTO testprov.prov (id, user, isvalid, paths, paramset, type, downscaling, createdat, lasteditedat) VALUES ($$CUUID, '$$CURRUUID', False, {'/home/bde2020/data/BINARY/'}, {'sst:$(RSTARTDT)','wps:1','wrf:0','d01:$$d01','d02:$$d02','d03:$$d03','d01rd:$(RDURATION)','d02rd:$(RDURATION)','d03rd:$(RDURATION)','d01k:$$d01','d02k:$$d02','d03k:$$d03'}, 'wps',[{agentname: 'wps', agenttype:'software', agentversion:'0.0.1', st:toTimestamp(now()), et:toTimestamp(now()), params:{'d01':'$$d01','d02':'$$d02','d03':'$$d03'}, issuccessful:False}], toTimestamp(now()), toTimestamp(now()))" ;\
	  ALISTI=`/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "select downscaling from testprov.prov where id=$$CUUID;"` ;\
	  /usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "delete downscaling from testprov.prov where id=$$CUUID" ;\
	  ALISTI=`echo $$ALISTI|sed 's|.*\[||;s|].*||;s|000+0000||g;s|issuccessful: False|issuccessful: True|' `;\
	  ALISTI=`echo $$ALISTI| sed "s|et: '\([^']*\)'|et:toTimestamp(now())|"`;\
	  ipaths=`ls -d met_em.$(REG)* | sed "s|^|'|g;s|$$|'|g"`; ipaths=`echo $$ipaths | sed 's| |,|g'`;\
	  echo "PROV_ID_WPS_ "$$CUUID;\
	else\
	  CPAR=`/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e " select id from testprov.prov where isvalid=True and user='$$CURRUUID' and paramset contains 'wps:1' and paramset contains 'sst:$(RSTARTDT)' and paramset contains 'd01:$$d01' and paramset contains 'd02:$$d02' and paramset contains 'd03:$$d03' and paramset contains 'd01rd:$(RDURATION)' and paramset contains 'd02rd:$(RDURATION)' and paramset contains 'd03rd:$(RDURATION)' and paramset contains 'd01k:$$d01' and paramset contains 'd02k:$$d02' and paramset contains 'd03k:$$d03' limit 1 allow filtering"| tail -n3 |head -n1 |sed 's| ||g'` ;\
	  echo "PROV_ID_WPS_ "$$CPAR;\
	fi;\
	make $(MAKEOPTS) run-ssh-cp;



run-wrf-nest::
	### Run WRF NESTDOWN ###
	#usage run-wrf RSTARTDT=StartDateOfModel RDURATION=DurationOfModelInHours REG=<d01d02|d02d03>
	d01=0; d02=0; d03=0; reg=$(REG);\
	CURRUUID=`cat $(CUSER)_curr.UUID`;\
	if [ "$(REG)" = d01d02 ];then \
	  d02=12;\
	  reg=d02;\
	  PFWRF=`make $(MAKEOPTS) -s run-wrf-no-export-copy REG=d01 | grep "PROV_ID_WRF_"`;\
	  PFWPS=`make $(MAKEOPTS) -s run-wps REG=d02 | grep "PROV_ID_WPS_"`;\
	  PFWRFI=`echo $$PFWRF | awk -F " " '{print $$2}'`;\
	  PFWPSI=`echo $$PFWPS | awk -F " " '{print $$2}'`;\
	fi;\
	if [ "$(REG)" = d02d03 ];then \
	  d03=12;\
	  reg=d03;\
	  PFWRF=`make $(MAKEOPTS) -s run-wrf REG=d02 | grep "PROV_ID_WRF_"`;\
	  PFWPS=`make $(MAKEOPTS) -s run-wps REG=d03 | grep "PROV_ID_"`;\
	  PFWRFI=`echo $$PFWRF | awk -F " " '{print $$2}'`;\
	  PFWPSI=`echo $$PFWPS | awk -F " " '{print $$2}'`;\
	fi;\
	CRES=`/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e " select id from testprov.prov where "\
	" bparentid=$$PFWPSI and parentid=$$PFWRFI and user='$$CURRUUID' and isvalid=True and paramset contains 'wrf:1' and paramset contains 'sst:$(RSTARTDT)' and paramset contains 'd01:$$d01'"\
	" and paramset contains 'd02:$$d02' and paramset contains 'd03:$$d03' and paramset contains 'd01rd:$(RDURATION)' "\
	" and paramset contains 'd02rd:$(RDURATION)' and paramset contains 'd03rd:$(RDURATION)' and paramset contains 'd01k:$$d01'"\
	" and paramset contains 'd02k:$$d02' and paramset contains 'd03k:$$d03' limit 1 allow filtering"| tail -n1| grep 1`;\
	if [ "$$CRES" = "" ]; then \
	   CUUID=`uuidgen`;\
	   /usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e \
	"INSERT INTO testprov.prov (id, user, isvalid, parentid, bparentid, paths, paramset, type, downscaling, createdat, lasteditedat) "\
	"VALUES ($$CUUID, '$$CURRUUID', False, $$PFWRFI,$$PFWPSI, {'/home/bde2020/data/BINARY/'}, "\
	"{'sst:$(RSTARTDT)','wps:0','wrf:1','d01:$$d01','d02:$$d02','d03:$$d03','d01rd:$(RDURATION)','d02rd:$(RDURATION)','d03rd:$(RDURATION)','d01k:$$d01','d02k:$$d02','d03k:$$d03'}, 'wrf',"\
	" [{agentname: 'wrf', agenttype:'software', agentversion:'0.0.1', st:toTimestamp(now()), et:toTimestamp(now()), params:{'d01':'$$d01','d02':'$$d02','d03':'$$d03'}, issuccessful:False}],"\
	"toTimestamp(now()), toTimestamp(now()))";\
	   ssh $(USERNAM)@$(MODELSRV) "cd $$CURRUUID/Run/bin && "\
	"./prepare.sh $(RSTARTDT) 0 1 $$d01 $$d02 $$d03 $(RDURATION) $(RDURATION) $(RDURATION) 0 0 0 &&"\
	" sed -i '13s|bde2020user1|$$CURRUUID|' fws.sh && nohup ./fws.sh && cd .. && echo done;";\
	   scp $(USERNAM)@$(MODELSRV):~/$$CURRUUID/Run/WRF/run_$${reg^^}/wrfout_d01* .;\
	   for f in wrfout_d01*; do \
	     ftc=`echo $$f | sed 's|d01|$(REG)|g'`;\
	     mv $$f $$ftc;\
	     make $(MAKEOPTS) ingest-file NETCDFFILE=$$ftc;\
	   done;\
	   ALISTI=`/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "select downscaling from testprov.prov where id=$$CUUID;"`;\
	   /usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "delete downscaling from testprov.prov where id=$$CUUID";\
	   ALISTI=`echo $$ALISTI|sed 's|.*\[||;s|].*||;s|000+0000||g;s|issuccessful: False|issuccessful: True|' `;\
	   ALISTI=`echo $$ALISTI| sed "s|et: '\([^']*\)'|et:toTimestamp(now())|"`;\
	   ipaths=`ls -d wrfout_$(REG)* | sed "s|^|'|g;s|$$|'|g"`; ipaths=`echo $$ipaths | sed 's| |,|g'`;\
	   /usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "UPDATE testprov.prov set isvalid=True, paths={$$ipaths},"\
	" lasteditedat=toTimestamp(now()), downscaling=[$$ALISTI] +downscaling"\
	" WHERE id=$$CUUID";\
	   echo "PROV_ID_WRF_ "$$CUUID;\
	else\
	   CPAR=`/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e " select id from testprov.prov where "\
	" isvalid=True and user='$$CURRUUID' and paramset contains 'wrf:1' and paramset contains 'sst:$(RSTARTDT)' and paramset contains 'd01:$$d01'"\
	" and paramset contains 'd02:$$d02' and paramset contains 'd03:$$d03' and paramset contains 'd01rd:$(RDURATION)' "\
	" and paramset contains 'd02rd:$(RDURATION)' and paramset contains 'd03rd:$(RDURATION)' and paramset contains 'd01k:$$d01'"\
	" and paramset contains 'd02k:$$d02' and paramset contains 'd03k:$$d03' limit 1 allow filtering"|tail -n3 |head -n1|sed 's| ||g'`;\
	   echo "PROV_ID_WRF_ "$$CPAR;\
	   nclist=`/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "select paths from testprov.prov where id=$$CPAR" | head -n4 | tail -n1 | sed "s|[\{,\},\','\r']||g"`;\
	   for ncf in $$nclist; do \
	      echo $$ncf;\
	      make $(MAKEOPTS) export-file NETCDFKEY=$$ncf NETCDFOUT=$$ncf;\
	      ftc=`echo $$ncf | sed 's|$(REG)|d01|g'`;\
	      mv $$ncf $$ftc;\
	   done;\
	   ssh $(USERNAM)@$(MODELSRV) "cd $$CURRUUID/Run/WRF/ && if [ ! -d run_$${reg^^} ]; then echo 'run_$${reg^^} does not exist!'; cp -r run_init_$${reg^^} run_$${reg^^};fi;";\
	   scp ./wrfout_d01* $(USERNAM)@$(MODELSRV):~/$$CURRUUID/Run/WRF/run_$${reg^^}/;\
	fi;\
	rm -f ./wrfout_*;


run-wrf::
	d01=0; d02=0; d03=0; reg=$(REG);\
	if [ "$(REG)" = d01 ]; then d01=1; fi;\
	if [ "$(REG)" = d02 ]; then d02=1; fi;\
	if [ "$(REG)" = d03 ]; then d03=1; fi;\
	CURRUUID=`cat $(CUSER)_curr.UUID`;\
	PF=`make $(MAKEOPTS) -s run-wps | grep "PROV_ID_WPS_"`;\
	PFI=`echo $$PF | awk -F " " '{print $$2}'`;\
	CRES=`/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e " select id from testprov.prov where bparentid=$$PFI and isvalid=True and user='$$CURRUUID' and paramset contains 'wrf:1' and paramset contains 'sst:$(RSTARTDT)' and paramset contains 'd01:$$d01' and paramset contains 'd02:$$d02' and paramset contains 'd03:$$d03' and paramset contains 'd01rd:$(RDURATION)' and paramset contains 'd02rd:$(RDURATION)' and paramset contains 'd03rd:$(RDURATION)' and paramset contains 'd01k:$$d01' and paramset contains 'd02k:$$d02' and paramset contains 'd03k:$$d03' limit 1 allow filtering"| tail -n1| grep 1`;\
	echo "the grep result " $$CRES;\
	if [ "$$CRES" = "" ];then \
	  CUUID=`uuidgen`;\
	  /usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "INSERT INTO testprov.prov (id, user, isvalid, bparentid, paths, paramset, type, downscaling, createdat, lasteditedat) VALUES ($$CUUID, '$$CURRUUID', False, $$PFI, {'/home/bde2020/data/BINARY/'}, {'sst:$(RSTARTDT)','wps:0','wrf:1','d01:$$d01','d02:$$d02','d03:$$d03','d01rd:$(RDURATION)','d02rd:$(RDURATION)','d03rd:$(RDURATION)','d01k:$$d01','d02k:$$d02','d03k:$$d03'}, 'wrf',[{agentname: 'wrf', agenttype:'software', agentversion:'0.0.1', st:toTimestamp(now()), et:toTimestamp(now()), params:{'d01':'$$d01','d02':'$$d02','d03':'$$d03'}, issuccessful:False}], toTimestamp(now()), toTimestamp(now()))";\
	  ssh $(USERNAM)@$(MODELSRV) "cd $$CURRUUID/Run/bin && "\
	  "./prepare.sh $(RSTARTDT) 0 1 $$d01 $$d02 $$d03 $(RDURATION) $(RDURATION) $(RDURATION) 0 0 0 &&"\
	  " sed -i '13s|bde2020user1|$$CURRUUID|' fws.sh && nohup ./fws.sh && cd .. && echo done;";\
	  scp $(USERNAM)@$(MODELSRV):~/$$CURRUUID/Run/WRF/run_$${reg^^}/wrfout_d01* .;\
	  for f in wrfout_d01*; do \
	    ftc=`echo $$f | sed 's|d01|$(REG)|g'`;\
	    make $(MAKEOPTS) ingest-file NETCDFFILE=$$ftc;\
	  done;\
	  ALISTI=`/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "select downscaling from testprov.prov where id=$$CUUID;"`;\
	  /usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "delete downscaling from testprov.prov where id=$$CUUID";\
	  ALISTI=`echo $$ALISTI|sed 's|.*\[||;s|].*||;s|000+0000||g;s|issuccessful: False|issuccessful: True|' `;\
	  ALISTI=`echo $$ALISTI| sed "s|et: '\([^']*\)'|et:toTimestamp(now())|"`;\
	  ipaths=`ls -d wrfout_$(REG)* | sed "s|^|'|g;s|$$|'|g"`; ipaths=`echo $$ipaths | sed 's| |,|g'`;\
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
	fi;\
	rm -f ./wrfout_*;

run-wrf-no-export-copy::
	d01=0; d02=0; d03=0; reg=$(REG);\
	if [ "$(REG)" = d01 ]; then d01=1; fi;\
	if [ "$(REG)" = d02 ]; then d02=1; fi;\
	if [ "$(REG)" = d03 ]; then d03=1; fi;\
	CURRUUID=`cat $(CUSER)_curr.UUID`;\
	PF=`make $(MAKEOPTS) -s run-wps-no-export-copy | grep "PROV_ID_WPS_"`;\
	PFI=`echo $$PF | awk -F " " '{print $$2}'`;\
	CRES=`/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e " select id from testprov.prov where bparentid=$$PFI and isvalid=True and user='$$CURRUUID' and paramset contains 'wrf:1' and paramset contains 'sst:$(RSTARTDT)' and paramset contains 'd01:$$d01' and paramset contains 'd02:$$d02' and paramset contains 'd03:$$d03' and paramset contains 'd01rd:$(RDURATION)' and paramset contains 'd02rd:$(RDURATION)' and paramset contains 'd03rd:$(RDURATION)' and paramset contains 'd01k:$$d01' and paramset contains 'd02k:$$d02' and paramset contains 'd03k:$$d03' limit 1 allow filtering"| tail -n1| grep 1`;\
	echo "the grep result " $$CRES;\
	if [ "$$CRES" = "" ];then \
	  CUUID=`uuidgen`;\
	  /usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "INSERT INTO testprov.prov (id, user, isvalid, bparentid, paths, paramset, type, downscaling, createdat, lasteditedat) VALUES ($$CUUID, '$$CURRUUID', False, $$PFI, {'/home/bde2020/data/BINARY/'}, {'sst:$(RSTARTDT)','wps:0','wrf:1','d01:$$d01','d02:$$d02','d03:$$d03','d01rd:$(RDURATION)','d02rd:$(RDURATION)','d03rd:$(RDURATION)','d01k:$$d01','d02k:$$d02','d03k:$$d03'}, 'wrf',[{agentname: 'wrf', agenttype:'software', agentversion:'0.0.1', st:toTimestamp(now()), et:toTimestamp(now()), params:{'d01':'$$d01','d02':'$$d02','d03':'$$d03'}, issuccessful:False}], toTimestamp(now()), toTimestamp(now()))";\
	  ALISTI=`/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "select downscaling from testprov.prov where id=$$CUUID;"`;\
	  /usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "delete downscaling from testprov.prov where id=$$CUUID";\
	  ALISTI=`echo $$ALISTI|sed 's|.*\[||;s|].*||;s|000+0000||g;s|issuccessful: False|issuccessful: True|' `;\
	  ALISTI=`echo $$ALISTI| sed "s|et: '\([^']*\)'|et:toTimestamp(now())|"`;\
	  ipaths=`ls -d wrfout_$(REG)* | sed "s|^|'|g;s|$$|'|g"`; ipaths=`echo $$ipaths | sed 's| |,|g'`;\
	  echo "PROV_ID_WRF_ "$$CUUID;\
	else\
	  CPAR=`/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e " select id from testprov.prov where isvalid=True and user='$$CURRUUID' and paramset contains 'wrf:1' and paramset contains 'sst:$(RSTARTDT)' and paramset contains 'd01:$$d01' and paramset contains 'd02:$$d02' and paramset contains 'd03:$$d03' and paramset contains 'd01rd:$(RDURATION)' and paramset contains 'd02rd:$(RDURATION)' and paramset contains 'd03rd:$(RDURATION)' and paramset contains 'd01k:$$d01' and paramset contains 'd02k:$$d02' and paramset contains 'd03k:$$d03' limit 1 allow filtering"|tail -n3 |head -n1|sed 's| ||g'`;\
	  echo "PROV_ID_WRF_ "$$CPAR;\
	fi;
