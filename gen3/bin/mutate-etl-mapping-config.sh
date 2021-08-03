#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

set -xe

# script for mutating the ETLMapping.yaml on jenkins env
# the incoming PR environment's ETLMapping.yaml is mutated to Jenkins environment

# how it is executed?
# gen3 mutate-etl-mapping-config {PR} {repoName}

echo "hello world"

prNumber=$1
shift
repoName=$1

if ! shift; then
 gen3_log_err "use: mutate-etl-mapping-config prNumber repoName"
 exit 1
fi

kubectl get cm etl-mapping -o jsonpath='{.data.etlMapping\.yaml}' > etlMapping.yaml
sed -i 's/.*- name: \(.*\)_subject$/  - name: '"${prNumber}"'.'"${repoName}"'.\1_subject/' etlMapping.yaml
sed -i 's/.*- name: \(.*\)_etl$/  - name: '"${prNumber}"'.'"${repoName}"'.\1_etl/' etlMapping.yaml
sed -i 's/.*- name: \(.*\)_file$/  - name: '"${prNumber}"'.'"${repoName}"'.\1_file/' etlMapping.yaml
kubectl delete configmap etl-mapping
kubectl create configmap etl-mapping --from-file=etlMapping.yaml=etlMapping.yaml
