#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

set -xe

# script for mutating the guppy configuration on jenkins env
# the incoming PR's guppy configuration is mutated to Jenkins environment

# how to run:
# gen3 mutate-guppy-config-for-pfb-export-test {PR} {repoName}

prNumber=$1
shift
repoName=$1

if ! shift; then
 gen3_log_err "use: mutate-guppy-config prNumber repoName"
 exit 1
fi

g3kubectl get configmap manifest-guppy -o yaml > original_guppy_config.yaml
# mutating permanent jenkins config
sed -i 's/\(.*\)"index": "\(.*\)_subject",$/\1"index": "'"${prNumber}"'.'"${repoName}"'.\2_subject",/' original_guppy_config.yaml
sed -i 's/\(.*\)"index": "\(.*\)_etl",$/\1"index": "'"${prNumber}"'.'"${repoName}"'.\2_etl",/' original_guppy_config.yaml
sed -i 's/\(.*\)"index": "\(.*\)_file",$/\1"index": "'"${prNumber}"'.'"${repoName}"'.\2_file",/' original_guppy_config.yaml
sed -i 's/\(.*\)"config_index": "\(.*\)_array-config",$/\1"config_index": "'"${prNumber}"'.'"${repoName}"'.\2_array-config",/' original_guppy_config.yaml

# mutating after guppy test (pre-defined canine config) and some qa-* env guppy configs
sed -i 's/\(.*\)"index": "\(.*\)_subject_alias",$/\1"index": "'"${prNumber}"'.'"${repoName}"'.'"${NAMESPACE}"'_subject",/' original_guppy_config.yaml
sed -i 's/\(.*\)"index": "\(.*\)_file_alias",$/\1"index": "'"${prNumber}"'.'"${repoName}"'.'"${NAMESPACE}"'_file",/' original_guppy_config.yaml
sed -i 's/\(.*\)"config_index": "\(.*\)_configs_alias",$/\1"config_index": "'"${prNumber}"'.'"${repoName}"'.'"${NAMESPACE}"'_array-config",/' original_guppy_config.yaml

g3kubectl delete configmap manifest-guppy
g3kubectl apply -f original_guppy_config.yaml
gen3 roll guppy
