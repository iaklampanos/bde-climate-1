#from __future__ import print_function
import os
import sys
import matplotlib

from ipywidgets import interact, interactive, fixed
import ipywidgets as widgets
from IPython.display import display

import subprocess
import sys
from subprocess import Popen, PIPE, STDOUT
import graphviz as gv
import json
import networkx as nx

HIVE='localhost:10000'
PILOT_PATH = '/home/stathis/bde-climate-1'
NC_FILENAME = '/home/stathis/sc5/rsdscs_Amon_HadGEM2-ES_rcp26_r2i1p1_200512-203011.nc'

CLUSTER_USER = 'stathis'
CLUSTER_IP = '172.17.20.106'
CLUSTER_DATA_DIR = '/home/stathis/Downloads'
CLUSTER_BUILD_DIR = '/home/stathis/Develop'

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
    
def updateIngestHTML(x):
    txarea.value = x

def ingest(filename):
    ''' make ingest-file NETCDFFILE=yourfilewithfullpath '''
    # print 'Ingesting', filename
    s = execu(ingest_command(netcdffile=filename))#, pattern="LOAD", fn=updateIngestHTML)

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

def ingest_command(clusteruser=CLUSTER_USER,
                   clusterip=CLUSTER_IP,
                   clim1_dd=CLUSTER_DATA_DIR,
                   clim1_bd=CLUSTER_BUILD_DIR,
                   netcdffile='somefile'):
    curr_user = os.environ['USER']
    sti0 = 'scp ./__FILE__ __UNAME__@__HOST__:__BUILD_DIR__/bde-climate-1'
    sti1 = 'ssh __UNAME__@__HOST__ -T "export CLIMATE1_CASSANDRA_DATA_DIR=__DATA_DIR__ && export CLIMATE1_BUILD_DIR=__BUILD_DIR__ && cd __BUILD_DIR__/bde-climate-1 && make -s ingest-file-withprov NETCDFFILE=__FILE__ CUSER=__CUSER__"'
    sti = sti0 + ' && ' + sti1
    sti = sti.replace('__UNAME__', clusteruser)
    sti = sti.replace( '__HOST__', clusterip)
    sti = sti.replace('__DATA_DIR__', clim1_dd)
    sti = sti.replace('__BUILD_DIR__', clim1_bd)
    sti = sti.replace('__FILE__', netcdffile)
    sti = sti.replace('__CUSER__', curr_user)
    # print(sti)
    return sti

def prov_command(clusteruser=CLUSTER_USER,
                 clusterip=CLUSTER_IP,
                 clim1_dd=CLUSTER_DATA_DIR,
                 clim1_bd=CLUSTER_BUILD_DIR,
                 netcdfkey='somekey'):
    # make export-file NETCDFKEY=yourkeysearch NETCDFOUT=nameofnetcdfoutfile
    sti = 'ssh  __UNAME__@__HOST__ -T "export CLIMATE1_CASSANDRA_DATA_DIR=__DATA_DIR__ && export CLIMATE1_BUILD_DIR=__BUILD_DIR__ && cd __BUILD_DIR__/bde-climate-1 && make -s  get-prov DATASET=__KEY__"'
    sti = sti.replace('__UNAME__', clusteruser)
    sti = sti.replace( '__HOST__', clusterip)
    sti = sti.replace('__DATA_DIR__', clim1_dd)
    sti = sti.replace('__BUILD_DIR__', clim1_bd)
    sti = sti.replace('__KEY__', netcdfkey)
    return sti   

def export_command(clusteruser=CLUSTER_USER,
                   clusterip=CLUSTER_IP,
                   clim1_dd=CLUSTER_DATA_DIR,
                   clim1_bd=CLUSTER_BUILD_DIR,
                   netcdfkey='somekey'):
    # make export-file NETCDFKEY=yourkeysearch NETCDFOUT=nameofnetcdfoutfile
    sti0 = 'echo "Retrieving __FILE__..." && scp __UNAME__@__HOST__:__BUILD_DIR__/bde-climate-1/__FILE__ .'
    sti1 = 'echo "Exporting __FILE__..." && ssh  __UNAME__@__HOST__ -T "export CLIMATE1_CASSANDRA_DATA_DIR=__DATA_DIR__ && export CLIMATE1_BUILD_DIR=__BUILD_DIR__ && cd __BUILD_DIR__/bde-climate-1 && make -s export-file NETCDFKEY=__KEY__ NETCDFOUT=__FILE__"'
    sti = sti1 + ' && ' + sti0
    sti = sti.replace('__UNAME__', clusteruser)
    sti = sti.replace( '__HOST__', clusterip)
    sti = sti.replace('__DATA_DIR__', clim1_dd)
    sti = sti.replace('__BUILD_DIR__', clim1_bd)
    sti = sti.replace('__KEY__', netcdfkey)
    sti = sti.replace('__FILE__', 'exp_' + netcdfkey)
    return sti

def datakeys_command(clusteruser=CLUSTER_USER,
                     clusterip=CLUSTER_IP,
                     clim1_dd=CLUSTER_DATA_DIR,
                     clim1_bd=CLUSTER_BUILD_DIR):
    # make export-file NETCDFKEY=yourkeysearch NETCDFOUT=nameofnetcdfoutfile
    sti = 'ssh  __UNAME__@__HOST__ -T "export CLIMATE1_CASSANDRA_DATA_DIR=__DATA_DIR__ && export CLIMATE1_BUILD_DIR=__BUILD_DIR__ && cd __BUILD_DIR__/bde-climate-1 && make -s cassandra-get-datasets"'
    sti = sti.replace('__UNAME__', clusteruser)
    sti = sti.replace( '__HOST__', clusterip)
    sti = sti.replace('__DATA_DIR__', clim1_dd)
    sti = sti.replace('__BUILD_DIR__', clim1_bd)
    return sti

global ncfiles
ncfiles = []
def filestolist(x):
    ncfiles.append(x.strip())


def netcdf_files():
    global ncfiles 
    ncfiles = []
    execu('ls *.nc', fn=filestolist)
    return ncfiles[:-1]


global dataset_keys
dataset_keys = []
def populate_cassandra_keys_list(l):
    dataset_keys.append(l.strip())

def get_cassandra_data_keys():
    global dataset_keys
    dataset_keys = []
    execu(datakeys_command(), fn=populate_cassandra_keys_list)
    return dataset_keys[:-1]


def update_export_HTML(x):
    tx_export.value = x.strip()

def export_clicked(b):
    execu(export_command(netcdfkey=dd_export.value), fn=update_export_HTML)
    
def display_export_form():
    # Find available datasets/keys
    # Display dropdown list
    # Export button
    global dd_export
    global bt_export
    global tx_export
    global datakeys

    datakeys = get_cassandra_data_keys()

    l = widgets.HTML(
        value = '<span style="color:#fff;">................................................... </span> '
    )
    dd_export = widgets.Dropdown(
        options=get_cassandra_data_keys(),
        description='Available keys:',
    )
    bt_export = widgets.Button(description="Export")
    tx_export = widgets.Textarea()
    container = widgets.HBox(children=[dd_export, l, bt_export, tx_export])

    bt_export.on_click(export_clicked)
    display(container)

def update_prov(l):
    global provlist
    l = l.strip()
    if l == '': return
    provlist.append(json.loads(l))
    # print '> ' + str(provlist)

    # if l == '': return
    # jsonl = json.loads(l)
    
    # g1.node(jsonl['id'])
    # g1.node('B')
    # g1.edge('A', 'B')
    # print(g1.source)
    # filename = g1.render(filename='img/g1',)
    # print filename

import matplotlib.image as mpimg
def prov_clicked(b):
    global provlist
    provlist = []
    execu(prov_command(netcdfkey=dd_prov.value), fn=update_prov)

    g1 = gv.Graph(format='png')
    for i in provlist:
        g1.node(i['id'])
        if i['parentid'] is not None:
            g1.node(i['parentid'])
            g1.edge(i['parentid'], i['id'])
        if i['bparentid'] is not None:
            g1.node(i['bparentid'])
            g1.edge(i['bparentid'], i['id'])
    # print g1.source
    g1.render(filename='img/g1',)

    global html_prov
    html_prov.value = '<img src="img/g1.png"/>'

def wrf_clicked(b):
    global dd_reg_wrf
    global dd_st_wrf
    global dd_dur_wrf

    reg = None
    stdate = None
    dur = None
    if dd_reg_wrf.value == 'Europe':
        reg = 'd01'
    elif dd_reg_wrf.value == 'Greece':
        reg = 'd02'
    else:
        pass

    stdate = dd_st_wrf.value.replace('-', '')
    dur = dd_dur_wrf.value
    execu(wrf_command(region=reg, startdate=stdate, duration=dur))
    
def display_wrf_form():
    global dd_reg_wrf
    global dd_st_wrf
    global dd_dur_wrf
    global bt_wrf
    global tx_wrf

    l = widgets.HTML(
        value = '<span style="color:#fff;">................................................... </span> '
    )

    dd_reg_wrf = widgets.Dropdown(
        options=["Europe", "Greece"],
        value="Europe",
        description='Available regions:',
    )
    dd_st_wrf = widgets.Dropdown(
        options=["2016-07-01","2016-07-02","2016-07-03","2016-07-04","2016-07-05","2016-07-06","2016-07-07"],
        value="2016-07-01",
        description='Starting date:',
    )
    dd_dur_wrf= widgets.Dropdown(
        options=['6', '12', '18', '24'],
        value='6',
        desciption='Duration:',
    )
    bt_wrf = widgets.Button(description="Run WRF")
    tx_wrf = widgets.HTML()
    container = widgets.HBox(children=[dd_reg_wrf, dd_st_wrf, dd_dur_wrf, bt_wrf])

    bt_wrf.on_click(wrf_clicked)
    display(container)
    display(tx_wrf)
    
    
def display_prov_form():
    global dd_prov
    global bt_prov
    global html_prov
    global datakeys

    datakeys = get_cassandra_data_keys()

    l = widgets.HTML(
        value = '<span style="color:#fff;">................................................... </span> '
    )
    dd_prov = widgets.Dropdown(
        options=get_cassandra_data_keys(),
        description='Available keys:',
    )
    bt_prov = widgets.Button(description="Display lineage")
    html_prov = widgets.HTML()
    container = widgets.HBox(children=[dd_prov, l, bt_prov])

    bt_prov.on_click(prov_clicked)
    display(container)
    display(html_prov)


def display_ingest_form():
    global w
    global b
    global txarea

    netcdf_files()

    l = widgets.HTML(
        value = '<span style="color:#fff;">................................................... </span> '
    )
    w = widgets.Dropdown(
        options=ncfiles,
        description='Choose file:',
    )
    b = widgets.Button(description='Ingest')
    txarea = widgets.Textarea()
    container = widgets.HBox(children=[w, l, b, txarea])

    b.on_click(ingest_clicked)
    display(container)
    
def ingest_clicked(b):
    ingest(filename=w.value)
    
def export(filename):
    ''' make export-file NETCDFKEY=yourkeysearch NETCDFOUT=nameofnetcdfoutfile '''
    ''' MAY support more selective use-case '''
    pass

def wrf_command(clusteruser=CLUSTER_USER,
                clusterip=CLUSTER_IP,
                clim1_dd=CLUSTER_DATA_DIR,
                clim1_bd=CLUSTER_BUILD_DIR,
                region ='R1',
                startdate = '20070101',
                duration = 6):
    # make export-file NETCDFKEY=yourkeysearch NETCDFOUT=nameofnetcdfoutfile
    curr_user = os.environ['USER']
    sti = 'ssh  __UNAME__@__HOST__ -T "export CLIMATE1_CASSANDRA_DATA_DIR=__DATA_DIR__ && export CLIMATE1_BUILD_DIR=__BUILD_DIR__ && cd __BUILD_DIR__/bde-climate-1 && make -s run-wrf RSTARTDT=__STARTDATE__ RDURATION=__RDURATION__ REG=__REGION__ CUSER=__CUSER__"'
    sti = sti.replace('__UNAME__', clusteruser)
    sti = sti.replace( '__HOST__', clusterip)
    sti = sti.replace('__DATA_DIR__', clim1_dd)
    sti = sti.replace('__BUILD_DIR__', clim1_bd)
    sti = sti.replace('__STARTDATE__', startdate)
    sti = sti.replace('__RDURATION__', duration)
    sti = sti.replace('__REGION__', region)
    sti = sti.replace('__CUSER__', curr_user)
    return sti

def _run_wrf():
    '''make run-wrf RSTARTDT=StartDateOfModel RDURATION=DurationOfModelInHours REG=<d01|d02|d03> '''
    pass

def _run_wrf_nest():
    '''run-wrf RSTARTDT=StartDateOfModel RDURATION=DurationOfModelInHours REG=<d01d02|d02d03>'''

def view_data(data=0):
    ''' matplotlib thingy '''
    print('a')
    pass

def hive_command(clusteruser='stathis', clusterip='172.17.20.106', clim1_bd='/home/stathis/Downloads', clim1_dd='/home/stathis/bde-climate-1', command='ls /home'):
    sti = 'ssh  __UNAME__@__HOST__ -T "export CLIMATE1_CASSANDRA_DATA_DIR=__DATA_DIR__ && export CLIMATE1_BUILD_DIR=__BUILD_DIR__ && cd __BUILD_DIR__ && docker exec -i hive __COMMND__"' 
    sti = sti.replace('__UNAME__', clusteruser)
    sti = sti.replace( '__HOST__', clusterip)
    sti = sti.replace('__DATA_DIR__', clim1_dd)
    sti = sti.replace('__BUILD_DIR__', clim1_bd)
    sti = sti.replace('__COMMND__', command)
    print(sti)
    return sti

def exec_bash(command):
    return os.popen(command).read()
    #p = Popen(command, shell=True, stdin=PIPE, stdout=PIPE, stderr=STDOUT, close_fds=True)
    #output = p.stdout.read()
    #return output

# Test:
# execu('ls / | grep "te"')
