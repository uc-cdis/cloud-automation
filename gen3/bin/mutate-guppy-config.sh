#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

set -xe

# TODO: Add comment here to explain what's going on

prNumber=$1
repoName=$2

kubectl get configmap manifest-guppy -o yaml > original_guppy_config.yaml
sed -i 's/\(.*\)"index": "\(.*\)_subject",$/\1"index": "'"${prNumber}"'.'"${repoName}"'.\2_subject",/' original_guppy_config.yaml
sed -i 's/\(.*\)"index": "\(.*\)_etl",$/\1"index": "'"${prNumber}"'.'"${repoName}"'.\2_etl",/' original_guppy_config.yaml
sed -i 's/\(.*\)"index": "\(.*\)_file",$/\1"index": "'"${prNumber}"'.'"${repoName}"'.\2_file",/' original_guppy_config.yaml
sed -i 's/\(.*\)"config_index": "\(.*\)_array-config",$/\1"config_index": "'"${prNumber}"'.'"${repoName}"'.\2_array-config",/' original_guppy_config.yaml
kubectl delete configmap manifest-guppy
kubectl apply -f original_guppy_config.yaml
gen3 roll guppy
