#!/bin/bash
#
#create guppy indices with dummy data to test explorer pagekubec
source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

export ESHOST="${ESHOST:-"esproxy-service:9200"}"

#create dev_case index with data and mappings
gen3 nrun elasticdump --input dev_case__mapping.json --output="${ESHOST}/dev_case" --type data
gen3 nrun elasticdump --input dev_case__data.json --output="${ESHOST}/dev_case" --type data