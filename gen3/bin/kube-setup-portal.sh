#!/bin/bash
#
# Reverse proxy needs to deploy last in order for nginx
# to be able to resolve the DNS domains of all the services
# at startup.  
# Unfortunately - the data-portal wants to connect to the reverse-proxy
# at startup time, so there's a chicken-egg thing going on, so
# will probably need to restart the data-portal pods first time
# the commons comes up.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

umask 0
gen3 kube-setup-secrets

defaultsDir="${GEN3_HOME}/kube/services/portal/defaults"
manifestsDir="$(dirname $(g3k_manifest_path))/portal"

declare -a confFileList=()
for defaultFile in "${defaultsDir}"/gitops*; do
  name="$(basename "${defaultFile}")"
  manifestFile="${manifestsDir}/${name}"
  confFileList+=("--from-file")
  if [[ -f "$manifestFile" ]]; then
    confFileList+=("$manifestFile")
  else
    confFileList+=("$defaultFile")
  fi
done

if g3kubectl get configmap portal-config > /dev/null 2>&1; then
  g3kubectl delete configmap portal-config
fi
echo "Creating portal-config ${confFileList[@]}"
g3kubectl create configmap portal-config "${confFileList[@]}"

gen3 roll portal
