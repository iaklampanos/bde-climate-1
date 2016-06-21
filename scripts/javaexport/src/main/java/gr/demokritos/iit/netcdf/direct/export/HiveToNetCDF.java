/**
 * 
 */
package gr.demokritos.iit.netcdf.direct.export;

import java.io.IOException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

import ucar.ma2.Array;
import ucar.ma2.InvalidRangeException;
import ucar.nc2.Dimension;
import ucar.nc2.NetcdfFileWriter;
import ucar.nc2.Variable;

/**
 * @author Yiannis Mouchakis
 *
 */
public class HiveToNetCDF {
	
	private String url;
	private String username = "";
	private String password = "";
	
	/**
	 * 
	 * @param url the hive url to use in the connection. 
	 * username and password are set as "" by default so use setters to change if needed.
	 */
	public HiveToNetCDF(String url) {
		this.url = url;
	}

	/**
	 * @param username hive username. by default empty string
	 */
	public void setUsername(String username) {
		this.username = username;
	}

	/**
	 * @param password hive password. by default empty string
	 */
	public void setPassword(String password) {
		this.password = password;
	}
	
	/**
	 * 
	 * reads hive tables and exports data into netcdf
	 * 
	 * @param writer netcdf file writer to be used
	 * @param dataset the name of the netcdf dataset
	 * @throws SQLException
	 * @throws IOException
	 * @throws InvalidRangeException
	 */
	public void writeData(NetcdfFileWriter writer, String dataset) throws SQLException, IOException, InvalidRangeException {
		
		String table_prefix = dataset.replace("-", "_").replace(".", "_") + "_"; 
		
                Connection connection = DriverManager.getConnection(url, username, password);
	    		
		for (Variable var :  writer.getNetcdfFile().getVariables()) {
			
			String var_name = var.getShortName();
			String table = table_prefix + var_name;
			
			Statement stmt = connection.createStatement();
			
			int dim_size = var.getDimensions().size();
			
			if (dim_size < 2) {
				
				Array results = Array.factory(var.getDataType(), var.getShape());			
			
				String query = "SELECT row_no, " + var_name + " FROM " + table + " "
						+ "WHERE " + var_name + " IS NOT NULL ORDER BY row_no";
				ResultSet resultSet = stmt.executeQuery(query);
				
				while (resultSet.next()) {			
					results.setObject(resultSet.getInt("row_no"), resultSet.getObject(var_name));					
				}
				
				resultSet.close();
				writer.write(var, results);
				
			} else {
				
				int[] origin = new int[dim_size];
				int[] shape = new int[dim_size];
				for (int i = 0; i < shape.length; i++) {
					shape[i] = 1;
				}
				Array result = Array.factory(var.getDataType(), shape);
				
				String query = "SELECT row_no, " + var.getDimensionsString().trim().replaceAll(" ", ",") 
						+ ", " + var_name + " FROM " + table + " WHERE " + var_name + " IS NOT NULL";
				
				ResultSet resultSet = stmt.executeQuery(query);
				
				while (resultSet.next()) {			
					
					int count = 0;
					for (Dimension dim : var.getDimensions()) {
						origin[count] = resultSet.getInt(dim.getShortName());
						count++;
					}
					result.setObject(0, resultSet.getObject(var_name));
					writer.write(var, origin, result);
									
				}
				resultSet.close();
			}
			
			stmt.close();

		}
		
		connection.close();
	}
	

}
