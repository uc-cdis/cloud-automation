#
# Common header at the top of all the kube-setup-* scripts
#
set -e

_KUBE_SETUP_INIT=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
# Jenkins friendly
export WORKSPACE="${WORKSPACE:-$HOME}"
export GEN3_HOME="${GEN3_HOME:-$(cd "${_KUBE_SETUP_INIT}/../.." && pwd)}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"


if [[ -z "$_KUBES_SH" ]]; then
  source "$GEN3_HOME/gen3/gen3setup.sh"
fi # else already sourced this file ...

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
