from __future__ import print_function
import subprocess
import os
import sys
import matplotlib

from ipywidgets import interact, interactive, fixed
import ipywidgets as widgets

HIVE='localhost:10000'

PILOT_PATH='/home/stathis/bde-climate-1'

def run_shell_command(s):

    c = s.split('|')
    cp = None # the current process

    for i in range(0, len(c)):
        c[i] = c[i].replace('**PIPE**', '|')
        cin = cout = None  

        if i > 0: 
            cin = cp.stdout
        if i < len(c)-1: 
            cout = subprocess.PIPE

        sys.stdout.flush()
        cp = subprocess.Popen(c[i], stdout=cout, stdin=cin, shell=True)

    cp.wait() 


def help():
    print('Hello, world')

def _create_user_structure():
   	''' make create-structure'''
	run_shell_command("make -C /home/stathis/bde-climate-1 create-structure")
    
def ingest(filename):
    ''' make ingest-file NETCDFFILE=yourfilewithfullpath ''' 
    print('Ingesting', filename)

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
    print('a')
    pass
