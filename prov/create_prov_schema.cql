CREATE KEYSPACE IF NOT EXISTS testprov WITH REPLICATION = {'class':'SimpleStrategy', 'replication_factor':1};

//CREATE TABLE IF NOT EXISTS testprov.prov;
CREATE  TYPE IF NOT EXISTS testprov.agentproc;


CREATE TYPE testprov.agentproc (
	agentname VARCHAR,
	agenttype VARCHAR, -- currently only have software agents
	agentversion VARCHAR,
	st timestamp, -- start of processing
	et timestamp, -- end of processing
	params MAP<VARCHAR, VARCHAR>, -- execution params and values
	misc TEXT,
	issuccessful boolean
);

CREATE TABLE IF NOT EXISTS testprov.prov (
	id UUID,
	isvalid boolean,
	user TEXT,
	paths SET<VARCHAR>,
	paramset SET<VARCHAR>,
	type VARCHAR,
	bparentid UUID,
	parentid UUID,
	preproc LIST<FROZEN <agentproc>>,
	downscaling LIST<FROZEN <agentproc>>,
	postproc LIST<FROZEN <agentproc>>,
	createdat timestamp,
	lasteditedat timestamp,
	PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS prov_paramset ON testprov.prov(paramset);
CREATE INDEX IF NOT EXISTS prov_paths ON testprov.prov(paths);
CREATE INDEX IF NOT EXISTS prov_valid ON testprov.prov(isvalid);

