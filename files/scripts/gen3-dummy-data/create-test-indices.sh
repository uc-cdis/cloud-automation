#!/bin/bash
#
#create guppy indices with dummy data to test explorer pagekubec
source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

export ESHOST="${ESHOST:-"esproxy-service:9200"}"

indices='dev_case dev_file dev_case-array-config'

#Copy all mapping and index files from s3
aws s3 cp s3://gen3-dummy-data/ . --recursive  

#Create indices
for index in indices
do
gen3 nrun elasticdump --input /home/ubuntu/cloud-automation/files/scripts/test-indices/$index__mapping.json --output=http://esproxy-service:9200/$index --type mapping
gen3 nrun elasticdump --input /home/ubuntu/cloud-automation/files/scripts/test-indices/$index__data.json --output=http://esproxy-service:9200/$index --type data
done

rm dev*