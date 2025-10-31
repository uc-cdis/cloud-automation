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
if [[ -z "$vpc_name" ]]; then
  if ! vpc_name="$(gen3 api environment)"; then
    if [[ -f "$(gen3_secrets_folder)/00configmap.yaml" ]]; then
      g3kubectl apply -f "$(gen3_secrets_folder)/00configmap.yaml"
    else
      gen3_log_err "ERROR: to determine vpc_name from environment, also unable to configure global configmap - missing $(gen3_secrets_folder)/00configmap.yaml"
      exit 1
    fi
  fi
  vpc_name="$(gen3 api environment)" || vpc_name=""  # catch errors below
fi

if [ -z "${vpc_name}" ]; then
  gen3_log_err "vpc_name variable not set - bailing out"
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
