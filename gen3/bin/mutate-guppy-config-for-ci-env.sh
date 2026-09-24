#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

set -xe
indexname=$1
# script for mutating the guppy configuration on jenkins env

# how to run:
# gen3 mutate-guppy-config-for-ci-env jenkins

g3kubectl get configmap manifest-guppy -o yaml > original_guppy_config.yaml
sed -i "s/\(.*\)\"index\": \"\(.*\)_subject\",$/\1\"index\": \"${indexname}_subject_alias\",/" original_guppy_config.yaml
sed -i "/\"index\": \".*file_alias\"/ { /midrc/! s/\"index\": \"\(.*\)_file\"/\"index\": \"${indexname}_file_alias\"/ }" original_guppy_config.yaml

g3kubectl delete configmap manifest-guppy
g3kubectl apply -f original_guppy_config.yaml
gen3 roll guppy
