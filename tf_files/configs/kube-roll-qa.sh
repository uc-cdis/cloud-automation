#!/bin/bash
#
# A little helper script that runs "g3k roll all"
# against every 'qa-*' namespace.
#
_KUBE_ROLL_QA=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
export GEN3_HOME="${GEN3_HOME:-$(cd "${_KUBE_ROLL_QA}/../.." && pwd)}"

if [[ -z "$_KUBES_SH" ]]; then
  source "$GEN3_HOME/kube/kubes.sh"
fi # else already sourced this file ...

export vpc_name=${vpc_name:-${1:-qaplanetv1}}

if [ -z "${vpc_name}" ]; then
  echo "ERROR: vpc_name variable not set - bailing out"
  exit 1
fi

#
# First - setup a clean and Jenkins-friendly workspace, so we don't inadvertantly
#   load secrets off the file system into the cluster.
#   We want to work under
#
export WORKSPACE="${WORKSPACE:-${XDG_RUNTIME_DIR:-/tmp}}"

namespaceList=$(g3kubectl get namespace -o json | jq -r '.items[].metadata.name')
for name in $namespaceList; do
  if [[ "$name" == "default" || $name =~ ^qa-.+$ ]]; then
    echo $name
    (
      export WORKSPACE=$(mktemp -d -p "$WORKSPACE" "qaroll_${name}_XXXXXX")
      # g3kubectl keys on KUBECTL_NAMESPACE environment variable
      export KUBECTL_NAMESPACE="$name"
      cd "$WORKSPACE"
      echo "Rolling namespace $name"
      g3k roll all
      echo "-------------"
      echo ""
    )
  fi
done
