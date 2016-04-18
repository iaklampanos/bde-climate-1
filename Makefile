# Main makefile for the first BDE climate pilot prototype

SHELL=/bin/bash
SED=/usr/bin/sed

help::
	@echo "Usage help goes here"

include configuration.mk

QUERY=
query::
	# search by (sparql?) string

SPARQL_FILE=myfile
query_sparql::
	# search by sparql file
