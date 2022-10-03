#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

set -xe

# script for mutating the guppy configuration on jenkins env
# the incoming PR's guppy configuration is mutated to Jenkins environment

# how to run:
# gen3 mutate-guppy-config-for-pfb-export-test

etlMapping="$(g3kubectl get cm etl-mapping -o jsonpath='{.data.etlMapping\.yaml}')"
guppyConfig="$(yq '{indices:[.mappings[]|{index:.name,type:.doc_type}],auth_filter_field:"auth_resource_path"}' <<< "$etlMapping")"
configIndex="$(jq -r '.indices[0].index' <<< "$guppyConfig" | rev | cut -d_ -f2- | rev)_array-config"
guppyConfig="$(jq --arg configIndex "$configIndex" '. += {config_index:$configIndex}' <<< "$guppyConfig")"

g3kubectl delete configmap manifest-guppy
gen3 gitops configmaps-from-json manifest-guppy "$guppyConfig"
gen3 roll guppy
