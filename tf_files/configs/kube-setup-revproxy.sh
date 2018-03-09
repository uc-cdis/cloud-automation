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

vpc_name=${vpc_name:-$1}
if [ -z "${vpc_name}" ]; then
   echo "Usage: bash kube-setup-revproxy.sh vpc_name"
   exit 1
fi
if [ ! -d ~/"${vpc_name}" ]; then
  echo "~/${vpc_name} does not exist"
  exit 1
fi

source "${G3AUTOHOME}/kube/kubes.sh"

cd ~/${vpc_name}
kubectl apply -f services/revproxy/00nginx-config.yaml
kubectl apply -f services/revproxy/revproxy-deploy.yaml

#
# apply_service deploys the revproxy service after
# inserting the certificate ARN from a config map
#
./services/revproxy/apply_service

patch_kube revproxy-deployment
