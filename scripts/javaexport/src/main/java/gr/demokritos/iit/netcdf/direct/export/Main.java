/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package gr.demokritos.iit.netcdf.direct.export;

import java.io.IOException;
import java.sql.SQLException;

import org.openrdf.query.MalformedQueryException;
import org.openrdf.query.QueryEvaluationException;
import org.openrdf.repository.RepositoryException;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.CommandLineParser;
import org.apache.commons.cli.DefaultParser;
import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.Option;
import org.apache.commons.cli.OptionGroup;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;
import ucar.ma2.InvalidRangeException;
import ucar.nc2.NetcdfFileWriter;

/**
 *
 * @author Stathis Grigoropoulos
 */
public class Main {
	/**
	 * prints help message
	 * @param options the available options
	 */
	private static void help(Options options) {
		HelpFormatter formatter = new HelpFormatter();
		formatter.printHelp("<application name>", options, true);
	}
    
    
	/**
	 * @param args
	 * @throws InvalidRangeException 
	 * @throws SQLException 
	 * @throws QueryEvaluationException 
	 * @throws MalformedQueryException 
	 * @throws RepositoryException 
	 */
	public static void main(String[] args) throws IOException, SQLException, InvalidRangeException, RepositoryException, MalformedQueryException, QueryEvaluationException {
		
                
		
		OptionGroup start_group = new OptionGroup();
		start_group.setRequired(true);
	
		Option help = Option.builder("h")
				.desc("prints help message")
				.longOpt("help")
				.required()
				.build();
		start_group.addOption(help);
		
		
		//search options
		Options search_options = new Options();
		
                
		Option term = Option.builder("t")
				.desc("term to search")
				.longOpt("term")
				.numberOfArgs(1)
				.required()
				.build();
		search_options.addOption(term);
		
		Option address = Option.builder("a")
				.desc("cassandra address")
				.longOpt("address")
				.numberOfArgs(1)
				.required()
				.build();
		search_options.addOption(address);

		Option port = Option.builder("p")
				.desc("cassandra port")
				.longOpt("port")
				.numberOfArgs(1)
				.type(Integer.class)
				.required()
				.build();
		search_options.addOption(port);

		Option haddress = Option.builder("d")
				.desc("hive address")
				.longOpt("haddress")
				.numberOfArgs(1)
				.required()
				.build();
		search_options.addOption(haddress);
                
                
		Option keyspace = Option.builder("k")
				.desc("cassandra keyspace to be used. by default \"netcdf_headers\"")
				.longOpt("keyspace")
				.numberOfArgs(1)
				.build();
		search_options.addOption(keyspace);

                Option output = Option.builder("o")
				.desc("the name of the output netcdf file")
				.longOpt("output")
				.numberOfArgs(1)
				.build();
		search_options.addOption(output);
                
                //begin parsing
		CommandLineParser parser = new DefaultParser();
			
		CommandLine start_cmdl = null;
		
                try {
			start_cmdl = parser.parse(search_options, args, true);
		} catch (ParseException e) {
			System.err.println("Parsing failed, correct usage is:");
			help(search_options);
			throw new IllegalArgumentException(e);
		}
		
		if (start_cmdl.hasOption(help.getOpt())) {
			
			help(search_options);
			
		}
                else if(start_cmdl.hasOption(term.getOpt())) {
                    
                    CommandLine search_cmdl = null;
			try {
				search_cmdl = parser.parse(search_options, args);
			} catch (ParseException e) {
				System.err.println("Parsing failed, correct usage is:");
				help(search_options);
				throw new IllegalArgumentException(e);
			}
               
                
            
                    NetcdfFileWriter writer = NetcdfFileWriter.createNew(NetcdfFileWriter.Version.netcdf3, search_cmdl.getOptionValue(output.getOpt(),search_cmdl.getOptionValue(term.getOpt())));
		
                    SemagrowToNetCDF semagrow = new SemagrowToNetCDF("http://172.18.0.15:8090/SemaGrow/sparql");	
                    //semagrow.getNetCDFDirect("rsdscs_Amon_HadGEM2-ES_rcp26_r2i1p1_200512-203011.nc", writer);
                    semagrow.getNetCDFDirect(search_cmdl.getOptionValue(term.getOpt()), 
                                             search_cmdl.getOptionValue(address.getOpt()), 
                                             Integer.parseInt(search_cmdl.getOptionValue(port.getOpt())),
                                             writer);
                    writer.setFill(true);
                    writer.setLargeFile(true);
                    writer.create();
                    HiveToNetCDF hive;
                    //hive = new HiveToNetCDF("jdbc:hive2://172.18.0.11:10000/");
                    
                    hive = new HiveToNetCDF("jdbc:hive2://"+ search_cmdl
                                                          .getOptionValue(haddress.getOpt()).trim() +":10000/");
                    hive.writeData(writer, "rsdscs_Amon_HadGEM2-ES_rcp26_r2i1p1_200512-203011.nc");
                    hive.writeData(writer, search_cmdl.getOptionValue(term.getOpt()));
                    writer.close();
                }
	}

}
