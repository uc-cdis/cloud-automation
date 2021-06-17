#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

set -xe

# script for mutating the guppy configuration on jenkins env
# the incoming PR's guppy configuration is mutated to Jenkins environment

# how it is executed?
# gen3 mutate-guppy-config {PR} {repoName}

prNumber=$1
shift
repoName=$1

if ! shift; then
 gen3_log_err "use: mutate-guppy-config prNumber repoName"
 exit 1
fi

kubectl get configmap manifest-guppy -o yaml > original_guppy_config.yaml
sed -i 's/\(.*\)"index": "\(.*\)_subject",$/\1"index": "'"${prNumber}"'.'"${repoName}"'.\2_subject",/' original_guppy_config.yaml
sed -i 's/\(.*\)"index": "\(.*\)_etl",$/\1"index": "'"${prNumber}"'.'"${repoName}"'.\2_etl",/' original_guppy_config.yaml
sed -i 's/\(.*\)"index": "\(.*\)_file",$/\1"index": "'"${prNumber}"'.'"${repoName}"'.\2_file",/' original_guppy_config.yaml
sed -i 's/\(.*\)"config_index": "\(.*\)_array-config",$/\1"config_index": "'"${prNumber}"'.'"${repoName}"'.\2_array-config",/' original_guppy_config.yaml
kubectl delete configmap manifest-guppy
kubectl apply -f original_guppy_config.yaml
gen3 roll guppy
