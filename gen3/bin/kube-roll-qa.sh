#!/bin/bash
#
# A little helper script that runs "g3k roll all"
# against every 'qa-*' namespace.
#
_KUBE_ROLL_QA=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
export GEN3_HOME="${GEN3_HOME:-$(cd "${_KUBE_ROLL_QA}/../.." && pwd)}"

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

export vpc_name=${vpc_name:-${1:-qaplanetv1}}

if [ -z "${vpc_name}" ]; then
  echo "ERROR: vpc_name variable not set - bailing out"
  exit 1
fi

#
# First - setup a clean and Jenkins-friendly workspace, so we don't inadvertantly
#   load secrets off the file system into the cluster.
#   The kube-setup- scripts look for secrets and service configuration in
#     $WORKSPACE/$vpc_name 
#   if they exist (most kube-setup scripts use $HOME if $WORKSPACE is not defined), 
#   so we try to be careful here that we don't blead
#   configuration between namespaces or pickup config from random
#   files left laying around the Jenkins workspace
#
export WORKSPACE="${WORKSPACE:-${XDG_RUNTIME_DIR:-/tmp}}"

result=0
namespaceList=$(g3kubectl get namespace -o json | jq -r '.items[].metadata.name')
for name in $namespaceList; do
  if [[ "$name" == "default" || $name =~ ^qa-.+$ ]]; then
    echo $name
    if ! (
      # Note we're in a (subshell) here - so this env goes away ...
      export WORKSPACE=$(mktemp -d -p "$WORKSPACE" "qaroll_${name}_XXXXXX")
      # g3kubectl keys on KUBECTL_NAMESPACE environment variable
      export KUBECTL_NAMESPACE="$name"
      cd "$WORKSPACE"
      echo "Rolling namespace $name"
      #
      # g3k roll all applies the appropriate cdis-manifest by doing something like:
      #     kubectl --namespace=$KUBECTL_NAMESPACE get configmap -o=jsonpath='{.data.hostname}'
      #
      g3k roll all
      # cleanup
      /bin/rm -rf "${WORKSPACE}"
    ); then
      result=1
    fi
    echo "-------------"
    echo ""
  fi
done

exit $result
