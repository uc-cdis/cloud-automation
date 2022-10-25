#!/bin/bash
#
#create guppy indices with dummy data to test explorer pagekubec

export ESHOST="${ESHOST:-"esproxy-service:9200"}"

#create dev_case index with data and mappings
gen3 nrun elasticdump --input dev_case__mapping.json --output="${ESHOST}/dev_case" --type mapping
gen3 nrun elasticdump --input dev_case__data.json --output="${ESHOST}/dev_case" --type data