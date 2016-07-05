from __future__ import print_function
from subprocess import Popen, PIPE, STDOUT
import os
import sys
import matplotlib


from ipywidgets import interact, interactive, fixed
import ipywidgets as widgets

HIVE='localhost:10000'

PILOT_PATH = '/home/stathis/bde-climate-1'
NC_FILENAME = '/home/stathis/sc5/rsdscs_Amon_HadGEM2-ES_rcp26_r2i1p1_200512-203011.nc'

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

def run_shell_command(s):
    subprocess.call(s)

def help():
    print('Hello, world')

def _create_user_structure():
    ''' make create-structure'''
    run_shell_command("make -C /home/stathis/bde-climate-1 create-structure")
    
def ingest_st(filename):
    '''test ingest'''
    os.popen("make -C /home/stathis/bde-climate-1 ingest-file NETCDFFILE=test")

def ingest(filename):
    ''' make ingest-file NETCDFFILE=yourfilewithfullpath '''
    print('Ingesting', filename)
    # s = run_shell_command("make -C /home/stathis/bde-climate-1 ingest-file NETCDFFILE=" + filename)
    s = run_shell_command('ls')
    print(s)
    
    
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

def hive_bash(clusteruser='stathis', clusterip='172.17.20.106', clim1_bd='/home/stathis/Downloads', clim1_dd='/home/stathis/bde-climate-1', command='ls /home'):
    sti = 'ssh __UNAME__@__HOST__ -t "export CLIMATE1_CASSANDRA_DATA_DIR=__DATA_DIR__ && export CLIMATE1_BUILD_DIR=__BUILD_DIR__ && cd __BUILD_DIR__ && docker exec -it hive __COMMND__"' 
    sti = sti.replace('__UNAME__', clusteruser)
    sti = sti.replace( '__HOST__', clusterip)
    sti = sti.replace('__DATA_DIR__', clim1_dd)
    sti = sti.replace('__BUILD_DIR__', clim1_bd)
    sti = sti.replace('__COMMND__', command)
    print(sti)
    print(exec_bash(sti))


def exec_bash(command):
    return os.popen(command).read()
    #p = Popen(command, shell=True, stdin=PIPE, stdout=PIPE, stderr=STDOUT, close_fds=True)
    #output = p.stdout.read()
    #return output

import subprocess
import sys
from subprocess import Popen, PIPE, STDOUT

def execu(command, pattern=None, fn=sys.stdout.write):
    """
    pattern is not really useful;
    fn is being called multiple times until the command has completed
    """
    p = subprocess.Popen(str(command), shell=True, stdin=PIPE, stdout=PIPE, stderr=STDOUT)
    while True:
        l = p.stdout.readline()
        if pattern == None:
            fn(l)
        else:
            if str(l).find(pattern) > 0:
                fn(l)
        if p.poll() != None:
            break

# Test:
# execu('ls / | grep "te"')