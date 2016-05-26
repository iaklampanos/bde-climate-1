CREATE KEYSPACE testprov WITH REPLICATION = {'class':'SimpleStrategy', 'replication_factor':1};

DROP TABLE IF EXISTS prov;
DROP TYPE IF EXISTS agentproc;

CREATE TYPE agentproc (
	agentname VARCHAR,
	agenttype VARCHAR, -- currently only have software agents
	agentversion VARCHAR,
	st timestamp, -- start of processing
	et timestamp, -- end of processing
	params MAP<VARCHAR, VARCHAR>, -- execution params and values
	issuccessful boolean
);

CREATE TABLE prov (
	id UUID,
	isvalid boolean,
	paths SET<VARCHAR>,
	paramset SET<VARCHAR>,
	type VARCHAR,
	parentid UUID,
	preproc LIST<FROZEN <agentproc>>,
	downscaling LIST<FROZEN <agentproc>>,
	postproc LIST<FROZEN <agentproc>>,
	createdat timestamp,
	lasteditedat timestamp,
	PRIMARY KEY (id)
);
CREATE INDEX prov_paramset ON prov(paramset);
CREATE INDEX prov_paths ON prov(paths);
CREATE INDEX prov_valid ON prov(isvalid);

-- Examples: 
------------
-- Insertion of raw data entities: (uuid() function for real data)
INSERT INTO prov (id, paramset, paths, createdat, lasteditedat, type) VALUES (5c805b69-99bb-4a14-ab83-0b64f3d74789, {'alpha','beta','gamma'}, {'foo/path'}, toTimestamp(now()), toTimestamp(now()), 'bdecl1:nc');

INSERT INTO prov (id, paramset, paths, createdat, lasteditedat, type, parentid) VALUES (5c805b69-99bb-4a14-ab83-0b64f3d74784, {'alpha','beta','gamma'}, {'foo/path'}, toTimestamp(now()), toTimestamp(now()), 'bdecl1:nc', 5c805b69-99bb-4a14-ab83-0b64f3d74789);

-- Append to the pre-processing activity:
UPDATE prov SET preproc = preproc + 
[{
agentname: 'CDO',
agentversion: '2.0',
agenttype: 'prov:SoftwareAgent',
issuccessful: true,
st: toTimeStamp(now()),
et: toTimeStamp(now())
}]
WHERE id=5c805b69-99bb-4a14-ab83-0b64f3d74784;

-- Don't think recursive querying /subquerying is allowed, so complete lineage information will need to be obtained programmatically.
