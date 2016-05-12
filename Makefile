# Main makefile for the first BDE climate pilot prototype

SHELL=/bin/bash
SED=$(shell which sed)

help::
	@echo "Usage help goes here"

include Configuration.mk

QUERY=
query::
	# search by (sparql?) string

SPARQL_FILE=myfile
query_sparql::
	# search by sparql file
