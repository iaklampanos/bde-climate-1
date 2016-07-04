import subprocess
import os
import sys
import matplotlib

HIVE='localhost:10000'

PILOT_PATH='/home/stathis/bde-climate-1'

def help():
    print 'Hello, world'

def _create_user_structure():
    ''' make create-structure'''
    
def ingest(filename):
    ''' make ingest-file NETCDFFILE=yourfilewithfullpath ''' 
    print 'Ingesting', filename

def export(filename):
    ''' make export-file NETCDFKEY=yourkeysearch NETCDFOUT=nameofnetcdfoutfile '''
    ''' MAY support more selective use-case '''
    pass

def downscale():
    pass

def _run_wrf():
    '''make run-wrf RSTARTDT=StartDateOfModel RDURATION=DurationOfModelInHours REG=<d01|d02|d03> '''
    pass

def _run_wrf_nest():
    '''run-wrf RSTARTDT=StartDateOfModel RDURATION=DurationOfModelInHours REG=<d01d02|d02d03>'''

def view_data(data=0):
    ''' matplotlib thingy '''
    print 'a'
    pass
