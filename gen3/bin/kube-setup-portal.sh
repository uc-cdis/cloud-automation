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
[[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets

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

#
# configmap would be better, but pre-1.10 k8s does not
# support binary data in configmap, so would have to
# deal with base64 decode by hand
#
if g3kubectl get secret portal-config > /dev/null 2>&1; then
  g3kubectl delete secret portal-config
  g3kubectl delete secret portal-sponsor-config
fi
# cleanup legacy setup
if g3kubectl get configmap portal-config > /dev/null 2>&1; then
  g3kubectl delete configmap portal-config
fi
echo "Creating portal-config ${confFileList[@]}"
g3kubectl create secret generic portal-config "${confFileList[@]}"
if [[ -d "$manifestsDir/gitops-sponsors/" ]]; then
  g3kubectl create secret generic portal-sponsor-config --from-file $manifestsDir/gitops-sponsors/
else
  g3kubectl create secret generic portal-sponsor-config
fi

dataUploadBucketName=$(gen3 secrets decode fence-config fence-config.yaml | yq -r .DATA_UPLOAD_BUCKET)
g3kubectl apply -f "${GEN3_HOME}/kube/services/portal/portal-service.yaml"
gen3 roll portal GEN3_DATA_UPLOAD_BUCKET $dataUploadBucketName
