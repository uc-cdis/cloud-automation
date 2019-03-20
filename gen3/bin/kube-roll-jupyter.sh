#!/bin/bash
#
# Initializes the Gen3 k8s secrets and services.
#
set -e

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

gen3 kube-setup-secrets

echo "INFO: using manifest at $(g3k_manifest_path)"

g3kubectl delete statefulset jupyterhub-deployment | true
g3kubectl delete daemonset jupyterhub-prepuller | true

gen3 update_config jupyterhub-config "${GEN3_HOME}/kube/services/jupyterhub/jupyterhub_config.py"
gen3 roll jupyterhub

configPath=$(g3k_manifest_path)
if [[ "$configPath" =~ .json$ ]]; then
  images=($(jq -r -e ".jupyterhub.containers[].image" < "$configPath"))
elif [[ "$configPath" =~ .yaml ]]; then
  images=($(yq -r -e ".jupyterhub.containers[].image" < "$configPath"))
else
  echo "$(red_color ERROR: file is not .json or .yaml: $configPath)" 1>&2
  return 1
fi
prepulleryaml=$(cat "${GEN3_HOME}/kube/services/jupyterhub/jupyterhub-prepuller.yaml")
for key in "${!images[@]}"; do
  newimage="      - name: \"image-${key}\"
        image: ${images[$key]}
        imagePullPolicy: IfNotPresent
        command:
          - /bin/sh
          - -c
          - echo 'Pulling complete'"
  prepulleryaml="${prepulleryaml}"$'\n'"${newimage}"
done
echo "$prepulleryaml" | g3kubectl apply -f -