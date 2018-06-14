#
# Common header at the top of all the kube-setup-* scripts
#
set -e

# Jenkins friendly
export WORKSPACE="${WORKSPACE:-$HOME}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

if [[ -z "$GEN3_NOPROXY" ]]; then
  export http_proxy=${http_proxy:-'http://cloud-proxy.internal.io:3128'}
  export https_proxy=${https_proxy:-'http://cloud-proxy.internal.io:3128'}
  export no_proxy=${no_proxy:-'localhost,127.0.0.1,169.254.169.254,.internal.io,logs.us-east-1.amazonaws.com'}
fi

export DEBIAN_FRONTEND=noninteractive
vpc_name=${vpc_name:-$1}

if [ -z "${vpc_name}" ]; then
  echo "ERROR: vpc_name variable not set - bailing out"
  exit 1
fi

export vpc_name

if [[ -f "${WORKSPACE}/${vpc_name}_output/creds.json" ]]; then # legacy path - fix it
  if [[ ! -f "${WORKSPACE}/${vpc_name}/creds.json" ]]; then
    # new path
    mkdir -p "${WORKSPACE}/${vpc_name}"
    cp "${WORKSPACE}/${vpc_name}_output/creds.json" "${WORKSPACE}/${vpc_name}/creds.json"
  fi
  mv "${WORKSPACE}/${vpc_name}_output/creds.json" "${WORKSPACE}/${vpc_name}_output/creds.json.bak"
fi
