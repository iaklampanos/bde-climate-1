# Configuration (docker) targets and scripts
SHELL=/bin/bash
CUSER=$(shell whoami)
REG=d01
RSTARTDT=20070103
RDURATION=12
USERNAM=bde2020
MODELSRV=tornado.ipta.demokritos.gr


run-wps::
	### Run WPS  ###
	#usage run-wps RSTARTDT=StartDateOfModel RDURATION=DurationOfModelInHours	
	d01=0;d02=0;d03=0;reg=$(REG);\
	if [ "$(REG)" = d01 ];then d01=1; fi;\
	if [ "$(REG)" = d02 ];then d02=1; fi;\
	if [ "$(REG)" = d03 ];then d03=1; fi;\
	CURRUUID=`cat curr.UUID`;\
	CRES=`/usr/bin/docker exec -it bdeclimate1_cassandra_1 cqlsh -e " select id from testprov.prov where "\
	" isvalid=True and paramset contains 'wps:1' and paramset contains 'sst:$(RSTARTDT)' and paramset contains 'd01:$$d01'"\
	" and paramset contains 'd02:$$d02' and paramset contains 'd03:$$d03' and paramset contains 'd01rd:$(RDURATION)' "\
	" and paramset contains 'd02rd:$(RDURATION)' and paramset contains 'd03rd:$(RDURATION)' and paramset contains 'd01k:$$d01'"\
	" and paramset contains 'd02k:$$d02' and paramset contains 'd03k:$$d03' limit 1 allow filtering"| tail -n1| grep 1`;\
	if [ "$$CRES" = "" ];then \
 	CUUID=`uuidgen`;\
 	/usr/bin/docker exec -it bdeclimate1_cassandra_1 cqlsh -e \
	"INSERT INTO testprov.prov (id, isvalid, paths, paramset, type, downscaling, createdat, lasteditedat) "\
	"VALUES ($$CUUID, False, {'/home/bde2020/data/BINARY/'}, "\
	"{'sst:$(RSTARTDT)','wps:1','wrf:0','d01:$$d01','d02:$$d02','d03:$$d03','d01rd:$(RDURATION)','d02rd:$(RDURATION)','d03rd:$(RDURATION)','d01k:$$d01','d02k:$$d02','d03k:$$d03'}, 'wps',"\
	" [{agentname: 'wps', agenttype:'software', agentversion:'0.0.1', st:toTimestamp(now()), et:toTimestamp(now()), params:{'d01':'$$d01','d02':'$$d02','d03':'$$d03'}, issuccessful:False}],"\
	"toTimestamp(now()), toTimestamp(now()))";\
 	 ssh $(USERNAM)@$(MODELSRV) "cd $$CURRUUID/Run/bin && "\
 	"./prepare.sh $(RSTARTDT) 1 0 $$d01 $$d02 $$d03 $(RDURATION) $(RDURATION) $(RDURATION) 0 0 0 &&"\
 	" sed -i '13s|bde2020user1|$$CURRUUID|' fws.sh && nohup ./fws.sh && cd .. && echo done;";\
 	scp $(USERNAM)@$(MODELSRV):~/$$CURRUUID/Run/WPS/RunData/met_em.$(REG)* .;\
 	for f in met_em.$(REG)*; do \
	 ncrename -O -d z-dimension0003,z_dimension0003 $$f $$f;\
	 ncrename -O -d z-dimension0012,z_dimension0012 $$f $$f;\
	 ncrename -O -d z-dimension0016,z_dimension0016 $$f $$f;\
	 ncrename -O -d z-dimension0024,z_dimension0024 $$f $$f;\
	 make ingest-file NETCDFFILE=$$f;\
 	done;\
 	ALISTI=`/usr/bin/docker exec -it bdeclimate1_cassandra_1 cqlsh -e "select downscaling from testprov.prov where id=$$CUUID;"`;\
 	/usr/bin/docker exec -it bdeclimate1_cassandra_1 cqlsh -e "delete downscaling from testprov.prov where id=$$CUUID";\
 	ALISTI=`echo $$ALISTI|sed 's|.*\[||;s|].*||;s|000+0000||g;s|issuccessful: False|issuccessful: True|' `;\
 	ALISTI=`echo $$ALISTI| sed "s|et: '\([^']*\)'|et:toTimestamp(now())|"`;\
 	ipaths=`ls -d met_em.$(REG)* | sed "s|^|'|g;s|$$|'|g"`; ipaths=`echo $$ipaths | sed 's| |,|g'`;\
 	/usr/bin/docker exec -it bdeclimate1_cassandra_1 cqlsh -e "UPDATE testprov.prov set isvalid=True, paths={$$ipaths},"\
	" lasteditedat=toTimestamp(now()),downscaling=[$$ALISTI] +downscaling"\
	" WHERE id=$$CUUID";\
 	echo "PROV_ID_WPS_ "$$CUUID;\
	else\
 	CPAR=`/usr/bin/docker exec -it bdeclimate1_cassandra_1 cqlsh -e " select id from testprov.prov where "\
	" isvalid=True and paramset contains 'wps:1' and paramset contains 'sst:$(RSTARTDT)' and paramset contains 'd01:$$d01'"\
	" and paramset contains 'd02:$$d02' and paramset contains 'd03:$$d03' and paramset contains 'd01rd:$(RDURATION)' "\
	" and paramset contains 'd02rd:$(RDURATION)' and paramset contains 'd03rd:$(RDURATION)' and paramset contains 'd01k:$$d01'"\
	" and paramset contains 'd02k:$$d02' and paramset contains 'd03k:$$d03' limit 1 allow filtering"|tail -n3 |head -n1|sed 's| ||g'`;\
 	echo "PROV_ID_WPS_ "$$CPAR;\
 	nclist=`/usr/bin/docker exec -it bdeclimate1_cassandra_1 cqlsh -e "select paths from testprov.prov where id=$$CPAR" | head -n4 | tail -n1 | sed "s|[\{,\},\','\r']||g"`;\
 	for ncf in $$nclist; do \
  	 echo $$ncf;\
  	 make export-file NETCDFKEY=$$ncf NETCDFOUT=$$ncf;\
	 ncrename -O -d z_dimension0003,z-dimension0003 $$f $$f;\
	 ncrename -O -d z_dimension0012,z-dimension0012 $$f $$f;\
	 ncrename -O -d z_dimension0016,z-dimension0016 $$f $$f;\
	 ncrename -O -d z_dimension0024,z-dimension0024 $$f $$f;\
 	done;\
 	ssh $(USERNAM)@$(MODELSRV) "cd $$CURRUUID/Run/WPS/ && if [ ! -d RunData ]; then echo 'RunData does not exist!'; cp -r RunData_init RunData;fi;";\
 	scp ./met_em.$(REG)* $(USERNAM)@$(MODELSRV):~/$$CURRUUID/Run/WPS/RunData/;\
	fi;\
	rm ./met_em.$(REG)*;


run-wrf-nest::
	### Run WRF  ###
	#usage run-wrf RSTARTDT=StartDateOfModel RDURATION=DurationOfModelInHours d01=1  d02=[0,1,12]	
	d01=0;d02=0;d03=0;reg=$(REG);\
	if [ "$(REG)" = d01d02 ];then \
	 PFWRF=`make -s run-wrf REG=d01 | grep "PROV_ID_WRF_";`\
	 PFWPS=`make -s run-wps REG=d02 | grep "PROV_ID_";`\
	 PFWRFI=`echo $$PFWRF | awk -F " " '{print $$2}'`;\
	 PFWPSI=`echo $$PFWPS | awk -F " " '{print $$2}'`;\
	fi;\
	if [ "$(REG)" = d02d03 ];then d02=1; fi;\
	CURRUUID=`cat curr.UUID`;


run-wrf::
	### Run WRF  ###
	#usage run-wrf RSTARTDT=StartDateOfModel RDURATION=DurationOfModelInHours d01=1  d02=[0,1,12]	
	d01=0;d02=0;d03=0;reg=$(REG);\
	if [ "$(REG)" = d01 ];then d01=1; fi;\
	if [ "$(REG)" = d02 ];then d02=1; fi;\
	if [ "$(REG)" = d03 ];then d03=1; fi;\
	CURRUUID=`cat curr.UUID`;\
	PF=`make -s run-wps | grep "PROV_ID_"`;\
	PFI=`echo $$PF | awk -F " " '{print $$2}'`;\
	CRES=`/usr/bin/docker exec -it bdeclimate1_cassandra_1 cqlsh -e " select id from testprov.prov where "\
	" bparentid=$$PFI and isvalid=True and paramset contains 'wrf:1' and paramset contains 'sst:$(RSTARTDT)' and paramset contains 'd01:$$d01'"\
	" and paramset contains 'd02:$$d02' and paramset contains 'd03:$$d03' and paramset contains 'd01rd:$(RDURATION)' "\
	" and paramset contains 'd02rd:$(RDURATION)' and paramset contains 'd03rd:$(RDURATION)' and paramset contains 'd01k:$$d01'"\
	" and paramset contains 'd02k:$$d02' and paramset contains 'd03k:$$d03' limit 1 allow filtering"| tail -n1| grep 1`;\
	if [ "$$CRES" = "" ];then \
 	CUUID=`uuidgen`;\
 	/usr/bin/docker exec -it bdeclimate1_cassandra_1 cqlsh -e \
	"INSERT INTO testprov.prov (id, isvalid, bparentid, paths, paramset, type, downscaling, createdat, lasteditedat) "\
	"VALUES ($$CUUID, False, $$PFI, {'/home/bde2020/data/BINARY/'}, "\
	"{'sst:$(RSTARTDT)','wps:0','wrf:1','d01:$$d01','d02:$$d02','d03:$$d03','d01rd:$(RDURATION)','d02rd:$(RDURATION)','d03rd:$(RDURATION)','d01k:$$d01','d02k:$$d02','d03k:$$d03'}, 'wrf',"\
	" [{agentname: 'wrf', agenttype:'software', agentversion:'0.0.1', st:toTimestamp(now()), et:toTimestamp(now()), params:{'d01':'$$d01','d02':'$$d02','d03':'$$d03'}, issuccessful:False}],"\
	"toTimestamp(now()), toTimestamp(now()))";\
 	 ssh $(USERNAM)@$(MODELSRV) "cd $$CURRUUID/Run/bin && "\
 	"./prepare.sh $(RSTARTDT) 0 1 $$d01 $$d02 $$d03 $(RDURATION) $(RDURATION) $(RDURATION) 0 0 0 &&"\
 	" sed -i '13s|bde2020user1|$$CURRUUID|' fws.sh && nohup ./fws.sh && cd .. && echo done;";\
 	scp $(USERNAM)@$(MODELSRV):~/$$CURRUUID/Run/WRF/run_$${reg^^}/wrfout_$(REG)* .;\
 	for f in wrfout_$(REG)*; do \
  	/home/stathis/Develop/bde-climate-1/sc5env/bin/python netpy.py $$f;\
  	make ingest-file NETCDFFILE=$$f;\
 	done;\
 	ALISTI=`/usr/bin/docker exec -it bdeclimate1_cassandra_1 cqlsh -e "select downscaling from testprov.prov where id=$$CUUID;"`;\
 	/usr/bin/docker exec -it bdeclimate1_cassandra_1 cqlsh -e "delete downscaling from testprov.prov where id=$$CUUID";\
 	ALISTI=`echo $$ALISTI|sed 's|.*\[||;s|].*||;s|000+0000||g;s|issuccessful: False|issuccessful: True|' `;\
 	ALISTI=`echo $$ALISTI| sed "s|et: '\([^']*\)'|et:toTimestamp(now())|"`;\
 	ipaths=`ls -d wrfout_$(REG)* | sed "s|^|'|g;s|$$|'|g"`; ipaths=`echo $$ipaths | sed 's| |,|g'`;\
 	/usr/bin/docker exec -it bdeclimate1_cassandra_1 cqlsh -e "UPDATE testprov.prov set isvalid=True, paths={$$ipaths},"\
	" lasteditedat=toTimestamp(now()),downscaling=[$$ALISTI] +downscaling"\
	" WHERE id=$$CUUID";\
 	echo "PROV_ID_WRF_ "$$CUUID;\
	else\
 	CPAR=`/usr/bin/docker exec -it bdeclimate1_cassandra_1 cqlsh -e " select id from testprov.prov where "\
	" isvalid=True and paramset contains 'wrf:1' and paramset contains 'sst:$(RSTARTDT)' and paramset contains 'd01:$$d01'"\
	" and paramset contains 'd02:$$d02' and paramset contains 'd03:$$d03' and paramset contains 'd01rd:$(RDURATION)' "\
	" and paramset contains 'd02rd:$(RDURATION)' and paramset contains 'd03rd:$(RDURATION)' and paramset contains 'd01k:$$d01'"\
	" and paramset contains 'd02k:$$d02' and paramset contains 'd03k:$$d03' limit 1 allow filtering"|tail -n3 |head -n1|sed 's| ||g'`;\
 	echo "PROV_ID_WRF_ "$$CPAR;\
 	nclist=`/usr/bin/docker exec -it bdeclimate1_cassandra_1 cqlsh -e "select paths from testprov.prov where id=$$CPAR" | head -n4 | tail -n1 | sed "s|[\{,\},\','\r']||g"`;\
 	for ncf in $$nclist; do \
  	echo $$ncf;\
  	make export-file NETCDFKEY=$$ncf NETCDFOUT=$$ncf;\
 	done;\
 	ssh $(USERNAM)@$(MODELSRV) "cd $$CURRUUID/Run/WRF/ && if [ ! -d run_$${reg^^} ]; then echo 'run_$${reg^^} does not exist!'; cp -r run_init_$${reg^^} run_$${reg^^};fi;";\
 	scp ./wrfout_$(REG)* $(USERNAM)@$(MODELSRV):~/$$CURRUUID/Run/WRF/run_$${reg^^}/;\
	fi;\
	rm ./wrfout_$(REG)*;


