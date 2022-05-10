#!/bin/bash
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"
gen3_load "gen3/lib/kube-setup-init"

# needs to
# * setup superset database
# * all the secrets, including client key/secret for OAuth2
# * networkpolicies (have no idea how)
# * redis (part of the helm)

