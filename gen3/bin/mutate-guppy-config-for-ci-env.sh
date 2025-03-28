#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

set -xe
indexname=$1
# script for mutating the guppy configuration on jenkins env

# how to run:
# gen3 mutate-guppy-config-for-ci-env jenkins

if [ "$indexname" == "jenkins" ]; then
 echo "Executing commands for jenkins..."
 g3kubectl get configmap manifest-guppy -o yaml > original_guppy_config.yaml
 sed -i "s/\(.*\)\"index\": \"\(.*\)_subject\",$/\1\"index\": \"${indexname}_subject_alias\",/" original_guppy_config.yaml
 sed -i "/\"index\": \".*file\"/ { /midrc/! s/\"index\": \"\(.*\)_file\"/\"index\": \"${indexname}_file_alias\"/ }" original_guppy_config.yaml
 sed -i "s/\(.*\)\"config_index\": \"\(.*\)-config\",$/\1\"config_index\": \"${indexname}_configs_alias\",/" original_guppy_config.yaml
else
 echo "Executing other commands..."
 g3kubectl get configmap manifest-guppy -o yaml > original_guppy_config.yaml
 yaml_content=$(kubectl get cm etl-mapping -o jsonpath='{.data.etlMapping\.yaml}')
 json_content=$(python -c "import sys, yaml, json; print(json.dumps(yaml.safe_load(sys.stdin.read())))" <<< "$yaml_content")
 subject_index=$(echo "$json_content" | jq -r '.mappings[].name' | grep subject)
 file_index=$(echo "$json_content" | jq -r '.mappings[].name' | grep file)
 sed -i "s/\(.*\)\"index\": \"\(.*\)_subject_alias\",$/\1\"index\": \"${subject_index}\",/" original_guppy_config.yaml
 sed -i "/\"index\": \".*file_alias\"/ { /midrc/! s/\"index\": \"\(.*\)_file_alias\"/\"index\": \"${file_index}\"/ }" original_guppy_config.yaml
fi
g3kubectl delete configmap manifest-guppy
g3kubectl apply -f original_guppy_config.yaml
gen3 roll guppy
