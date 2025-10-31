#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

set -xe

# script for mutating the ETLMapping.yaml on jenkins env
# the incoming PR environment's ETLMapping.yaml is mutated to Jenkins environment

# how it is executed?
# gen3 mutate-etl-mapping-config {PR} {repoName}

prNumber=$1
shift
repoName=$1

if ! shift; then
 gen3_log_err "use: mutate-etl-mapping-config prNumber repoName"
 exit 1
fi

g3kubectl get cm etl-mapping -o jsonpath='{.data.etlMapping\.yaml}' > etlMapping.yaml

prefix="${prNumber}.${repoName}."
if grep "$prefix" etlMapping.yaml; then
 gen3_log_info "ETL Mapping has already been mutated by a previous run of this script"
 exit 0
fi

yq -yi '.mappings[].name |= "'"${prefix}"'" + .' etlMapping.yaml
g3kubectl delete configmap etl-mapping
g3kubectl create configmap etl-mapping --from-file=etlMapping.yaml=etlMapping.yaml
