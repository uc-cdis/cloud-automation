#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

set -xe

# script for mutating the guppy configuration on jenkins env
# This will configure the pre-defined Canine ETL'ed data against Guppy

# how to run:
# gen3 mutate-guppy-config-for-guppy-test

kubectl get configmap manifest-guppy -o yaml > original_guppy_config.yaml
sed -i 's/\(.*\)"index": "\(.*\)_subject",$/\1"index": "jenkins_subject",/' original_guppy_config.yaml
sed -i 's/\(.*\)"index": "\(.*\)_file",$/\1"index": "jenkins_file",/' original_guppy_config.yaml
sed -i 's/\(.*\)"config_index": "\(.*\)_array-config",$/\1"config_index": "jenkins_array-config",/' original_guppy_config.yaml
kubectl delete configmap manifest-guppy
kubectl apply -f original_guppy_config.yaml
gen3 roll guppy
