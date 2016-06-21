/**
 * 
 */
package gr.demokritos.iit.netcdf.direct.export;

import java.io.IOException;
import java.lang.reflect.InvocationTargetException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import org.apache.commons.lang3.ClassUtils;
import org.openrdf.query.BindingSet;
import org.openrdf.query.MalformedQueryException;
import org.openrdf.query.QueryEvaluationException;
import org.openrdf.query.QueryLanguage;
import org.openrdf.query.TupleQuery;
import org.openrdf.query.TupleQueryResult;
import org.openrdf.repository.Repository;
import org.openrdf.repository.RepositoryConnection;
import org.openrdf.repository.RepositoryException;
import org.openrdf.repository.sparql.SPARQLRepository;

import ucar.ma2.DataType;
import ucar.nc2.Attribute;
import ucar.nc2.Dimension;
import ucar.nc2.NetcdfFileWriter;
import ucar.nc2.NetcdfFileWriter.Version;
import ucar.nc2.Variable;

import com.datastax.driver.core.Cluster;
import com.datastax.driver.core.Host;
import com.datastax.driver.core.Metadata;
import com.datastax.driver.core.Session;
import com.datastax.driver.core.ResultSet;
import com.datastax.driver.core.Row;

/**
 * @author Yiannis Mouchakis
 *
 */
public class SemagrowToNetCDF {
	
	private String base_uri = "http://cassandra.semagrow.eu/";
	private String keyspace;
	private String endpoint;
	
	public SemagrowToNetCDF(String endpoint) {
		this.endpoint = endpoint;
		this.keyspace = "keyspace";
	}
	
	/**
	 * @return the base_uri
	 */
	public String getBaseURI() {
		return base_uri;
	}

	/**
	 * @param base_uri the base_uri that will be used in Semagrow, by default "http://cassandra.semagrow.eu/"
	 */
	public void setBaseURI(String base_uri) {
		this.base_uri = base_uri;
	}

	/**
	 * @return Cassandra keyspace to query, by default "netcdf_headers"
	 */
	public String getKeyspace() {
		return keyspace;
	}

	/**
	 * @param keyspace the keyspace to set
	 */
	public void setKeyspace(String keyspace) {
		this.keyspace = keyspace;
	}


	/**
	 * Searches Cassandra from Semagrow to discover datasets containing a term
	 * @param term term to search if contained in any dataset
	 * @return a set with all the datasets containing the term
	 * @throws IOException
	 * @throws RepositoryException 
	 * @throws MalformedQueryException 
	 * @throws QueryEvaluationException 
	 */
	public Set<String> termSearch(String term) throws IOException, RepositoryException, MalformedQueryException, QueryEvaluationException {
		
		String base_keyspace = base_uri + keyspace;
		
		String query_str = "select distinct ?dataset where { \n" + 
				"  {\n" + 
				"    ?s <" + base_keyspace + "/dimensions#name> ?dim_name .\n" + 
				"    ?s <" + base_keyspace + "/dimensions#dataset> ?dataset \n" + 
				"    FILTER regex(str(?dim_name), \""+ term + "\", \"i\")\n" +
				"  }\n" + 
				"  UNION \n" + 
				"  {\n" + 
				"    ?s <" + base_keyspace + "/global_attributes#name> ?g_attr_name .\n" + 
				"    ?s <" + base_keyspace + "/global_attributes#dataset> ?dataset \n" + 
				"    FILTER regex(str(?g_attr_name), \""+ term + "\", \"i\")\n" +
				"  }\n" + 
				"  UNION \n" + 
				"  {\n" + 
				"    ?s <" + base_keyspace + "/global_attributes#value> ?g_attr_value .\n" + 
				"    ?s <" + base_keyspace + "/global_attributes#dataset> ?dataset .\n" + 
				"    FILTER regex(str(?g_attr_value), \""+ term + "\", \"i\")\n" + 
				"  }\n" + 
				"  UNION \n" + 
				"  {\n" + 
				"    ?s <" + base_keyspace + "/variable_attributes#varname> ?varname .\n" + 
				"    ?s <" + base_keyspace + "/cdfheader/variable_attributes#dataset> ?dataset \n" + 
				"    FILTER regex(str(?varname), \""+ term + "\", \"i\")\n" +
				"  }\n" + 
				"  UNION \n" + 
				"  {\n" + 
				"    ?s <" + base_keyspace + "/variable_attributes#attrname> ?attrname .\n" + 
				"    ?s <" + base_keyspace + "/variable_attributes#dataset> ?dataset \n" + 
				"    FILTER regex(str(?attrname), \""+ term + "\", \"i\")\n" +
				"  }\n" + 
				"  UNION \n" + 
				"  {\n" + 
				"    ?s <" + base_keyspace + "/variable_attributes#attrvalue> ?attrvalue.\n" + 
				"    ?s <" + base_keyspace + "/cdfheader/variable_attributes#dataset> ?dataset \n" + 
				"    FILTER regex(str(?attrvalue), \""+ term + "\", \"i\")\n" + 
				"  }\n" + 
				"}";
		
		Repository repository = new SPARQLRepository(endpoint);
		repository.initialize();
		RepositoryConnection connection = repository.getConnection();
		
		TupleQuery query = connection.prepareTupleQuery(QueryLanguage.SPARQL, query_str);
		TupleQueryResult result = query.evaluate();
		
		Set<String> datasets = new HashSet<>();
		
		while (result.hasNext()) {
			BindingSet bindingSet = result.next();
			datasets.add(bindingSet.getValue("dataset").stringValue());
		}
		
		result.close();
		connection.close();
		repository.shutDown();
		
		return datasets;
		
	}
	
	/**
	 * 
	 * Create a NetCDF file with complete header using version "netcdf3".
	 * 
	 * @param dataset the name of the created dataset
         * @param CassAddr
         * @param CassPort
	 * @param netcdf_path the path to the created netcdf file
	 * @return a NetcdfFileWriter for the created file, not in define mode
	 * @throws IOException
	 * @throws RepositoryException
	 * @throws MalformedQueryException
	 * @throws QueryEvaluationException
	 */
	public NetcdfFileWriter getNetCDF(String dataset,String CassAddr, Integer CassPort, String netcdf_path) 
			throws IOException, RepositoryException, MalformedQueryException, QueryEvaluationException {		
		
		return getNetCDFDirect(dataset, CassAddr, CassPort,netcdf_path, NetcdfFileWriter.Version.netcdf3);		
	}
	
	/**
	 * 
	 * Create a NetCDF file with complete header.
	 * 
	 * @param dataset the name of the created dataset
         * @param CassAddr
         * @param CassPort
	 * @param netcdf_path the path to the created netcdf file
	 * @param version the Version for the created file
	 * @return a NetcdfFileWriter for the created file, not in define mode
	 * @throws IOException
	 * @throws RepositoryException
	 * @throws MalformedQueryException
	 * @throws QueryEvaluationException
	 */
	public NetcdfFileWriter getNetCDFDirect(String dataset, String CassAddr, Integer CassPort, String netcdf_path, Version version) 
			throws IOException, RepositoryException, MalformedQueryException, QueryEvaluationException {	
		
		NetcdfFileWriter writer = NetcdfFileWriter.createNew(version, netcdf_path);
                //getNetCDF(dataset, writer);
		getNetCDFDirect(dataset, CassAddr, CassPort, writer);
		return writer;			
	}
	
	/**
	 * Create a NetCDF file with complete header.
	 * @param dataset the name of the created dataset
	 * @param writer the Netcdf writer to be used
	 * @throws RepositoryException 
	 * @throws MalformedQueryException 
	 * @throws QueryEvaluationException 
	 */
	public void getNetCDF(String dataset, NetcdfFileWriter writer) 
			throws RepositoryException, MalformedQueryException, QueryEvaluationException {
		
		Repository repository = new SPARQLRepository(endpoint);
		repository.initialize();
		RepositoryConnection connection = repository.getConnection();
		
		String base_keyspace = base_uri + keyspace;
		
		//get dimensions
		String dim_query_str = "SELECT * WHERE {\n" + 
				"  ?s <" + base_keyspace + "/dimensions#dataset> \"" + dataset + "\".\n" + 
				"  ?s <" + base_keyspace + "/dimensions#name> ?dim_name .\n" + 
				"  ?s <" + base_keyspace + "/dimensions#length> ?dim_length .\n" + 
				"  ?s <" + base_keyspace + "/dimensions#is_unlimited> ?dim_is_unlimited .\n" + 
				"}";
		
		TupleQuery query = connection.prepareTupleQuery(QueryLanguage.SPARQL, dim_query_str);
		TupleQueryResult result = query.evaluate();
		
		while (result.hasNext()) {
			BindingSet bindingSet = result.next();
			String dim_name = bindingSet.getValue("dim_name").stringValue();
			//not using unlimited dimensions for know because of problems in re-importing data
			/*boolean unlimited = bindingSet.getValue("dim_is_unlimited").stringValue().equalsIgnoreCase("true");
			writer.addDimension(null, dim_name, new Integer(bindingSet.getValue("dim_length").stringValue()),
					true, unlimited, false);*/
			writer.addDimension(null, dim_name, new Integer(bindingSet.getValue("dim_length").stringValue()));
		}
		
		result.close();
		
		//get global attributes
		String g_attr_query_str = "SELECT * WHERE {\n" + 
				"  ?s <" + base_keyspace + "/global_attributes#dataset> \"" + dataset + "\" .\n" + 
				"  ?s <" + base_keyspace + "/global_attributes#name> ?name .\n" + 
				"  ?s <" + base_keyspace + "/global_attributes#type> ?type .\n" + 
				"  ?s <" + base_keyspace + "/global_attributes#value> ?value .\n" + 
				"}";
		
		TupleQuery g_attr_query = connection.prepareTupleQuery(QueryLanguage.SPARQL, g_attr_query_str);
		TupleQueryResult g_attr_result = g_attr_query.evaluate();
		
		while (g_attr_result.hasNext()) {
			
			BindingSet bindingSet = g_attr_result.next();
			
			String name = bindingSet.getValue("name").stringValue();
			String type = bindingSet.getValue("type").stringValue();
			String value = bindingSet.getValue("value").stringValue();
			
			DataType dt = DataType.getType(type);
			Class<?> tmp_class = dt.getPrimitiveClassType();
			Class<?> c = ClassUtils.primitiveToWrapper(tmp_class);
			try {
				Object o = c.getConstructor(String.class).newInstance(value);
				writer.addGroupAttribute(null, new Attribute(name, Collections.singletonList(o)));
			} catch (NoSuchMethodException | SecurityException | InstantiationException
					| IllegalAccessException | IllegalArgumentException | InvocationTargetException e) {
				System.err.println("Could not store attribute " + name + " as " + dt.getClassType().getCanonicalName()
						+ ". Storing attribute value as String");
				e.printStackTrace();
				writer.addGroupAttribute(null, new Attribute(name, value));
			}
			
		}
		
		g_attr_result.close();
		
		//get variables and their attributes
		String var_query_str = "SELECT * WHERE {\n" + 
				"  ?s <" + base_keyspace + "/variable_attributes#dataset> \"" + dataset + "\".\n" + 
				"  ?s <" + base_keyspace + "/variable_attributes#varname> ?varname .\n" + 
				"  ?s <" + base_keyspace + "/variable_attributes#attrname> ?attrname .\n" + 
				"  ?s <" + base_keyspace + "/variable_attributes#attrtype> ?attrtype .\n" + 
				"  ?s <" + base_keyspace + "/variable_attributes#attrvalue> ?attrvalue .\n" + 
				"  ?s <" + base_keyspace + "/variable_attributes#shape> ?shape .\n" + 
				"  ?s <" + base_keyspace + "/variable_attributes#type> ?type .\n" + 
				"}";
		
		TupleQuery var_query = connection.prepareTupleQuery(QueryLanguage.SPARQL, var_query_str);
		TupleQueryResult var_result = var_query.evaluate();
		
		Set<String> inserted_vars = new HashSet<>();
		
		while (var_result.hasNext()) {
			
			BindingSet bindingSet = var_result.next();
			
			String name = bindingSet.getValue("varname").stringValue();
			String shape = bindingSet.getValue("shape").stringValue();
			String type = bindingSet.getValue("type").stringValue();
			
			Variable var = null;
			if (inserted_vars.contains(name)) {
				var = writer.findVariable(name);
			} else {
				var = writer.addVariable(null, name, DataType.getType(type), shape);
				inserted_vars.add(name);
			}
						
			String attrname = bindingSet.getValue("attrname").stringValue();
			String attrtype = bindingSet.getValue("attrtype").stringValue();
			String attrvalue = bindingSet.getValue("attrvalue").stringValue();
			
			DataType dt = DataType.getType(attrtype);
			Class<?> tmp_class = dt.getPrimitiveClassType();
			Class<?> c = ClassUtils.primitiveToWrapper(tmp_class);
			try {
				Object o = c.getConstructor(String.class).newInstance(attrvalue);
				var.addAttribute(new Attribute(attrname, Collections.singletonList(o)));
			} catch (NoSuchMethodException | SecurityException | InstantiationException
					| IllegalAccessException | IllegalArgumentException | InvocationTargetException e) {
				System.err.println("Could not store attribute " + attrname + " as " + dt.getClassType().getCanonicalName()
						+ ". Storing attribute value as String");
				e.printStackTrace();
				var.addAttribute(new Attribute(attrname, attrvalue));
			}
			
			
		}
		
		var_result.close();
		
		connection.close();
		repository.shutDown();
		
	}

        /**
	 * Create a NetCDF file with complete header directly from Cassandra.
	 * @param dataset the name of the created dataset
         * @param CassAddr
         * @param CassPort
	 * @param writer the Netcdf writer to be used
	 * @throws RepositoryException 
	 * @throws MalformedQueryException 
	 * @throws QueryEvaluationException 
	 */
        public void getNetCDFDirect(String dataset, String CassAddr, Integer CassPort,  NetcdfFileWriter writer) 
			throws RepositoryException, MalformedQueryException, QueryEvaluationException {
            
            Cluster cluster;
            Session session;
            cluster = Cluster.builder().addContactPoint(CassAddr).withPort(CassPort).build();
            session = cluster.connect("netcdf_headers");
            
            
            
            
            ResultSet results;
            results = session.execute("SELECT * FROM dimensions WHERE dataset='"+dataset+"';");
            
            for (Row row : results) {
			
                        
                        //Integer len = Integer.parseInt(row.getString("length").toString());
			//not using unlimited dimensions for know because of problems in re-importing data
			/*boolean unlimited = bindingSet.getValue("dim_is_unlimited").stringValue().equalsIgnoreCase("true");
			writer.addDimension(null, dim_name, new Integer(bindingSet.getValue("dim_length").stringValue()),
					true, unlimited, false);*/
			writer.addDimension(null, row.getString("name"),row.getInt("length"));
		}
		
            
            
            
            results = session.execute("SELECT * FROM global_attributes WHERE dataset='"+dataset+"';");
            for (Row row : results) {
                
                //System.out.format("%s %s\n", row.getString("name"), row.getString("value"));
                
                
                String name  = row.getString("name");
		String type  = row.getString("type");
		String value = row.getString("value");
			
		DataType dt = DataType.getType(type);
		Class<?> tmp_class = dt.getPrimitiveClassType();
		Class<?> c = ClassUtils.primitiveToWrapper(tmp_class);
		try {
                    Object o = c.getConstructor(String.class).newInstance(value);
                    writer.addGroupAttribute(null, new Attribute(name, Collections.singletonList(o)));
		} catch (NoSuchMethodException | SecurityException | InstantiationException
		| IllegalAccessException | IllegalArgumentException | InvocationTargetException e) {
                    System.err.println("Could not store attribute " + name + " as " + dt.getClassType().getCanonicalName()
                    + ". Storing attribute value as String");
                    writer.addGroupAttribute(null, new Attribute(name, value));
		}
			
            }
            
            results = session.execute("SELECT * FROM variable_attributes WHERE dataset='"+dataset+"';");
            Set<String> inserted_vars = new HashSet<>();
            for (Row row : results) {
                
			
		String name = row.getString("varname");
		String shape = row.getString("shape");
		String type = row.getString("type");
			
		Variable var = null;
		if (inserted_vars.contains(name)) {
			var = writer.findVariable(name);
		} else {
			var = writer.addVariable(null, name, DataType.getType(type), shape);
			inserted_vars.add(name);
		}
						
		String attrname = row.getString("attrname");
		String attrtype = row.getString("attrtype");
		String attrvalue = row.getString("attrvalue");
			
		DataType dt = DataType.getType(attrtype);
		Class<?> tmp_class = dt.getPrimitiveClassType();
		Class<?> c = ClassUtils.primitiveToWrapper(tmp_class);
		try {
			Object o = c.getConstructor(String.class).newInstance(attrvalue);
			var.addAttribute(new Attribute(attrname, Collections.singletonList(o)));
		} catch (NoSuchMethodException | SecurityException | InstantiationException
			| IllegalAccessException | IllegalArgumentException | InvocationTargetException e) {
                    System.err.println("Could not store attribute " + attrname + " as " + dt.getClassType().getCanonicalName()
					+ ". Storing attribute value as String");
                    e.printStackTrace();
                    var.addAttribute(new Attribute(attrname, attrvalue));
		}
			
			
		}
                
                
                
            cluster.close();
            
            
        }
        
        
        
}
