# Main makefile for the first BDE climate pilot prototype

SHELL=/bin/bash
SED=$(shell which sed)
MAKEOPTS=-C $(shell pwd)

help::
	@echo "Usage help goes here"

include Configuration.mk
include Data.mk
include Execution.mk

QUERY=
query::
	# search by (sparql?) string

SPARQL_FILE=myfile
query_sparql::
	# search by sparql file
