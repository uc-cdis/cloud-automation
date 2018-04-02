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

set -e

_KUBE_SETUP_REVPROXY=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
export GEN3_HOME="${GEN3_HOME:-$(cd "${_KUBE_SETUP_REVPROXY}/../.." && pwd)}"

if [[ -z "$_KUBES_SH" ]]; then
  source "$GEN3_HOME/kube/kubes.sh"
fi # else already sourced this file ...

vpc_name=${vpc_name:-$1}
if [ -z "${vpc_name}" ]; then
   echo "Usage: bash kube-setup-revproxy.sh vpc_name"
   exit 1
fi
if [ ! -d ~/"${vpc_name}" ]; then
  echo "~/${vpc_name} does not exist"
  exit 1
fi

cd ~/${vpc_name}
g3kubectl apply -f services/revproxy/00nginx-config.yaml
g3k roll revproxy

#
# apply_service deploys the revproxy service after
# inserting the certificate ARN from a config map
#
./services/revproxy/apply_service
