#Queries used for the make targets of the SC5 pilot


PROV_SEL_::
	d01=0;d02=0;d03=0;reg=$(REG);\
        if [ "$(REG)" = "d01" ]; then d01=1; fi;\
        if [ "$(REG)" = "d02" ]; then d02=1; fi;\
        if [ "$(REG)" = "d03" ]; then d03=1; fi;\
        if [ "$(REG)" = "d01d02" ]; then d02=12; fi;\
        if [ "$(REG)" = "d02d03" ]; then d03=12; fi;\
	/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "SELECT id from testprov.prov where isvalid=True and user='$(CUSER)' and paramset contains '$(TYPE):1' and paramset contains 'sst:$(RSTARTDT)' and paramset contains 'd01:$$d01' and paramset contains 'd02:$$d02' and paramset contains 'd03:$$d03' and paramset contains 'd01rd:$(RDURATION)' and paramset contains 'd02rd:$(RDURATION)' and paramset contains 'd03rd:$(RDURATION)' and paramset contains 'd01k:$$d01' and paramset contains 'd02k:$$d02' and paramset contains 'd03k:$$d03' limit 1 allow filtering";
        

PROV_SEL_NEST_::
	d01=0;d02=0;d03=0;reg=$(REG);\
        if [ "$(REG)" = "d01" ]; then d01=1; fi;\
        if [ "$(REG)" = "d02" ]; then d02=1; fi;\
        if [ "$(REG)" = "d03" ]; then d03=1; fi;\
        if [ "$(REG)" = "d01d02" ]; then d02=12; fi;\
        if [ "$(REG)" = "d02d03" ]; then d03=12; fi;\
	/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e " select id from testprov.prov where bparentid=$(BPWRFID) and parentid=$(PWRFID) and user='$(CUSER)' and isvalid=True and paramset contains 'wrf:1' and paramset contains 'sst:$(RSTARTDT)' and paramset contains 'd01:$$d01' and paramset contains 'd02:$$d02' and paramset contains 'd03:$$d03' and paramset contains 'd01rd:$(RDURATION)' and paramset contains 'd02rd:$(RDURATION)' and paramset contains 'd03rd:$(RDURATION)' and paramset contains 'd01k:$$d01' and paramset contains 'd02k:$$d02' and paramset contains 'd03k:$$d03' limit 1 allow filtering"


PROV_INS_::
	d01=0;d02=0;d03=0;wpsf=0;wrff=0;reg=$(REG);\
        if [ "$(TYPE)" = "wps" ]; then wpsf=1; fi;\
        if [ "$(TYPE)" = "wrf" ]; then wrff=1; fi;\
        if [ "$(REG)" = "d01" ]; then d01=1; fi;\
        if [ "$(REG)" = "d02" ]; then d02=1; fi;\
        if [ "$(REG)" = "d03" ]; then d03=1; fi;\
	/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "INSERT INTO testprov.prov (id, user, isvalid, paths, paramset, type, downscaling, createdat, lasteditedat) VALUES ($(CUUID), '$(CUSER)', False, {'/home/bde2020/data/BINARY/'}, {'sst:$(RSTARTDT)','wps:$$wpsf','wrf:$$wrff','d01:$$d01','d02:$$d02','d03:$$d03','d01rd:$(RDURATION)','d02rd:$(RDURATION)','d03rd:$(RDURATION)','d01k:$$d01','d02k:$$d02','d03k:$$d03'}, '$(TYPE)',[{agentname: 'wps', agenttype:'software', agentversion:'0.0.1', st:toTimestamp(now()), et:toTimestamp(now()), params:{'d01':'$$d01','d02':'$$d02','d03':'$$d03'}, issuccessful:False}], toTimestamp(now()), toTimestamp(now()))";


PROV_UPD_::
	AL=`echo $(ALISTI) | sed 's|_pb_|(|g;s|_pe_|)|g'`; path=`echo "{"$(ipaths)"}"`;\
	/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "UPDATE testprov.prov set isvalid=True, paths=$$path, lasteditedat=toTimestamp(now()),downscaling=[$$AL] +downscaling WHERE id=$(CUUID)" ;


PROV_OPER_DOWN_::
	/usr/bin/docker exec -i bdeclimate1_cassandra_1 cqlsh -e "$(OPER) downscaling from testprov.prov where id=$(CUUID)";


ONTEST::
	DATASET_TIMES_INS___:_"INSERT INTO netcdf_headers.dataset_times (dataset, start_date, end_date, step) VALUES('$$FN', '$$STRDAT', '$$ENDDAT','$$STEPDAT')"
	PROV_M_INS___:_"INSERT INTO testprov.prov (id, user, isvalid, paths, type, createdat, lasteditedat) VALUES ($$CUUID, '$(CUSER)', True, {'$(NETCDFFILE)'}, 'manual_ingest', toTimestamp(now()), toTimestamp(now()))"
	PROV_WPS_SEL___:_"SELECT id from testprov.prov where isvalid=True and user='$$CURRUUID' and paramset contains 'wps:1' and paramset contains 'sst:$(RSTARTDT)' and paramset contains 'd01:$$d01' and paramset contains 'd02:$$d02' and paramset contains 'd03:$$d03' and paramset contains 'd01rd:$(RDURATION)' and paramset contains 'd02rd:$(RDURATION)' and paramset contains 'd03rd:$(RDURATION)' and paramset contains 'd01k:$$d01' and paramset contains 'd02k:$$d02' and paramset contains 'd03k:$$d03' limit 1 allow filtering"
	PROV_WPS_INS___:_"INSERT INTO testprov.prov (id, user, isvalid, paths, paramset, type, downscaling, createdat, lasteditedat) VALUES ($$CUUID, '$$CURRUUID', False, {'/home/bde2020/data/BINARY/'}, {'sst:$(RSTARTDT)','wps:1','wrf:0','d01:$$d01','d02:$$d02','d03:$$d03','d01rd:$(RDURATION)','d02rd:$(RDURATION)','d03rd:$(RDURATION)','d01k:$$d01','d02k:$$d02','d03k:$$d03'}, 'wps',[{agentname: 'wps', agenttype:'software', agentversion:'0.0.1', st:toTimestamp(now()), et:toTimestamp(now()), params:{'d01':'$$d01','d02':'$$d02','d03':'$$d03'}, issuccessful:False}], toTimestamp(now()), toTimestamp(now()))"
	PROV_WRF_SEL___:_"SELECT id from testprov.prov where isvalid=True and user='$$CURRUUID' and paramset contains 'wrf:1' and paramset contains 'sst:$(RSTARTDT)' and paramset contains 'd01:$$d01' and paramset contains 'd02:$$d02' and paramset contains 'd03:$$d03' and paramset contains 'd01rd:$(RDURATION)' and paramset contains 'd02rd:$(RDURATION)' and paramset contains 'd03rd:$(RDURATION)' and paramset contains 'd01k:$$d01' and paramset contains 'd02k:$$d02' and paramset contains 'd03k:$$d03' limit 1 allow filtering"
	PROV_WRF_INS___:_"INSERT INTO testprov.prov (id, user, isvalid, parentid, bparentid, paths, paramset, type, downscaling, createdat, lasteditedat) VALUES ($$CUUID, '$$CURRUUID', False, $$PFWRFI,$$PFWPSI, {'/home/bde2020/data/BINARY/'}, {'sst:$(RSTARTDT)','wps:0','wrf:1','d01:$$d01','d02:$$d02','d03:$$d03','d01rd:$(RDURATION)','d02rd:$(RDURATION)','d03rd:$(RDURATION)','d01k:$$d01','d02k:$$d02','d03k:$$d03'}, 'wrf', [{agentname: 'wrf', agenttype:'software', agentversion:'0.0.1', st:toTimestamp(now()), et:toTimestamp(now()), params:{'d01':'$$d01','d02':'$$d02','d03':'$$d03'}, issuccessful:False}], toTimestamp(now()), toTimestamp(now()))"

