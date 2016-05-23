# Main makefile for the first BDE climate pilot prototype

SHELL=/bin/bash
SED=$(shell which sed)
GIT=$(shell which git)
MVN=$(shell which mvn)
JAVA=$(shell which java)

help::
	@echo "Usage help goes here"

include Configuration.mk
include Data.mk

QUERY=
query::
	# search by (sparql?) string

SPARQL_FILE=myfile
query_sparql::
	# search by sparql file
