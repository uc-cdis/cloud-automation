#!/bin/bash
#
#create guppy indices with dummy data to test explorer pagekubec
source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

export ESHOST="${ESHOST:-"esproxy-service:9200"}"

#create dev_case index with data and mappings
gen3 nrun elasticdump --input /home/ubuntu/cloud-automation/files/scripts/test-indices/dev_case__mapping.json --output=http://esproxy-service:9200/dev_case --type mapping
gen3 nrun elasticdump --input /home/ubuntu/cloud-automation/files/scripts/test-indices/dev_case__data.json --output=http://esproxy-service:9200/dev_case --type data

#create dev_file index with data and mappings
gen3 nrun elasticdump --input /home/ubuntu/cloud-automation/files/scripts/test-indices/dev_file__mapping.json --output=http://esproxy-service:9200/dev_file --type mapping
gen3 nrun elasticdump --input /home/ubuntu/cloud-automation/files/scripts/test-indices/dev_file__data.json --output=http://esproxy-service:9200/dev_file --type data

#create dev_case-array-config index with data and mappings
gen3 nrun elasticdump --input /home/ubuntu/cloud-automation/files/scripts/test-indices/dev_case-array-config__mapping.json --output=http://esproxy-service:9200/dev_case-array-config --type mapping
gen3 nrun elasticdump --input /home/ubuntu/cloud-automation/files/scripts/test-indices/dev_case-array-config__data.json --output=http://esproxy-service:9200/dev_case-array-config --type data