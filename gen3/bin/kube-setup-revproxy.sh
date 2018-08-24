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

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

g3kubectl apply -f "${GEN3_HOME}/kube/services/revproxy/00nginx-config.yaml"
g3k roll revproxy

#
# apply_service deploys the revproxy service after
# inserting the certificate ARN from a config map
#

if ! g3kubectl get services revproxy-service > /dev/null 2>&1; then
  g3kubectl apply -f "${GEN3_HOME}/kube/services/revproxy/revproxy-service.yaml"
else
  #
  # Do not do this automatically as it will trigger an elb
  # change in existing commons
  #
  echo "Ensure the commons DNS references the -elb revproxy which support http proxy protocol"
fi

bash "${GEN3_HOME}/kube/services/revproxy/apply_service"
