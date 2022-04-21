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

oldGuppyConfig="$(g3kubectl get configmap manifest-guppy -o jsonpath='{.data.json}')"
newGuppyConfig="$(jq '.indices[].index |= "'"${prNumber}.${repoName}."'" + .' <<< "$oldGuppyConfig")"
newGuppyConfig="$(jq '.config_index |= "'"${prNumber}.${repoName}."'" + .' <<< "$newGuppyConfig")"

g3kubectl delete configmap manifest-guppy
gen3 configmaps-from-json manifest-guppy "$newGuppyConfig"
gen3 roll guppy
