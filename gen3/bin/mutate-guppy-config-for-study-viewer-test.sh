#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

set -xe

# script for mutating the guppy configuration on jenkins env

# how to run:
# gen3 mutate-guppy-config-for-study-viewer-test

g3kubectl get configmap manifest-guppy -o yaml > original_guppy_config.yaml
sed -i 's/\(.*\)"index": "jenkins_cmc_alias",$/\1"index": "jenkins_cmc_permanent_alias",/' original_guppy_config.yaml

g3kubectl delete configmap manifest-guppy

g3kubectl apply -f original_guppy_config.yaml
gen3 roll guppy