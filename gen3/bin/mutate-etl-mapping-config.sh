#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

set -xe

# TODO: Add comment here to explain what's going on

echo "hello world"

prNumber=$1
repoName=$2

kubectl get cm etl-mapping -o jsonpath='{.data.etlMapping\.yaml}' > etlMapping.yaml
sed -i 's/.*name: \(.*\)_subject$/    name: '"${prNumber}"'.'"${repoName}"'.\1_subject/' etlMapping.yaml
sed -i 's/.*name: \(.*\)_etl$/    name: '"${prNumber}"'.'"${repoName}"'.\1_etl/' etlMapping.yaml
sed -i 's/.*name: \(.*\)_file$/    name: '"${prNumber}"'.'"${repoName}"'.\1_file/' etlMapping.yaml
kubectl delete configmap etl-mapping
kubectl create configmap etl-mapping --from-file=etlMapping.yaml=etlMapping.yaml
