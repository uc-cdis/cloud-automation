#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

set -xe

# script for mutating the guppy configuration on jenkins env
# This will configure the pre-defined Canine ETL'ed data against Guppy

# how to run:
# gen3 mutate-guppy-config-for-guppy-test

g3kubectl get configmap manifest-guppy -o yaml > original_guppy_config.yaml
sed -i 's/\(.*\)"index": "\(.*\)_etl",$/\1"index": "jenkins_subject_alias",/' original_guppy_config.yaml
sed -i 's/\(.*\)"index": "\(.*\)_file",$/\1"index": "jenkins_file_alias",/' original_guppy_config.yaml
sed -i 's/\(.*\)"config_index": "\(.*\)_array-config",$/\1"config_index": "jenkins_configs_alias",/' original_guppy_config.yaml

# mutating after guppy test (pre-defined canine config) and some qa-* env guppy configs
sed -i 's/\(.*\)"index": "\(.*\)_subject_alias",$/\1"index": "'"${prNumber}"'.'"${repoName}"'.\2_subject",/' original_guppy_config.yaml
sed -i 's/\(.*\)"index": "\(.*\)_file_alias",$/\1"index": "'"${prNumber}"'.'"${repoName}"'.\2_file",/' original_guppy_config.yaml
sed -i 's/\(.*\)"config_index": "\(.*\)_configs_alias",$/\1"config_index": "'"${prNumber}"'.'"${repoName}"'.\2_array-config",/' original_guppy_config.yaml

g3kubectl delete configmap manifest-guppy
g3kubectl apply -f original_guppy_config.yaml
gen3 roll guppy
