#
# Common header at the top of all the kube-setup-* scripts
#
set -e

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

if [[ -z "$GEN3_NOPROXY" ]]; then
  export http_proxy=${http_proxy:-'http://cloud-proxy.internal.io:3128'}
  export https_proxy=${https_proxy:-'http://cloud-proxy.internal.io:3128'}
  export no_proxy=${no_proxy:-"localhost,127.0.0.1,169.254.169.254,.internal.io,logs.us-east-1.amazonaws.com,kibana.planx-pla.net,.eks.amazonaws.com,${KUBERNETES_SERVICE_HOST:-127.0.0.2}"}
fi

export DEBIAN_FRONTEND=noninteractive
if [[ -z "$vpc_name" && $# -lt 1 ]]; then
  vpc_name="$(g3kubectl get configmap global -o json | jq -r .data.environment)"
fi

vpc_name=${vpc_name:-$1}
if [ -z "${vpc_name}" ]; then
  echo "ERROR: vpc_name variable not set - bailing out"
  exit 1
fi

export vpc_name

#
# Move files from {vpc_name}_output/ folder to {vpc_name}/ folder
#
for name in creds.json 00configmap.yaml; do
  if [[ -f "${WORKSPACE}/${vpc_name}_output/${name}" ]]; then # legacy path - fix it
    if [[ ! -f "${WORKSPACE}/${vpc_name}/${name}" ]]; then
      # new path
      mkdir -p "${WORKSPACE}/${vpc_name}"
      cp "${WORKSPACE}/${vpc_name}_output/${name}" "${WORKSPACE}/${vpc_name}/${name}"
    fi
    mv "${WORKSPACE}/${vpc_name}_output/${name}" "${WORKSPACE}/${vpc_name}_output/${name}.bak"
  fi
done
