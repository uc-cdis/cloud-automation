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
gen3_load "gen3/lib/g3k_manifest"

# Deploy ELB Service if flag set in manifest
manifestPath=$(g3k_manifest_path)
deployELB="$(jq -r ".[\"global\"][\"deploy_elb\"]" < "$manifestPath" | tr '[:upper:]' '[:lower:]')"


#
# Setup indexd basic-auth gateway user creds enforced
# by the revproxy to grant indexd_admin policy users update
# access to indexd.
# That authz flow is deprecated in favor of centralized-auth
# indexd policies.
#
setup_indexd_gateway() {
  if [[ -n "$JENKINS_HOME" || ! -f "$(gen3_secrets_folder)/creds.json" ]]; then
    # don't try to setup these secrets off the admin vm
    return 0
  fi

  local secret
  local secretsFolder="$(gen3_secrets_folder)/g3auto/gateway"
  if ! secret="$(g3kubectl get secret gateway-g3auto -o json 2> /dev/null)" \
    || [[ -z "$secret" || "false" == "$(jq -r '.data | has("creds.json")' <<< "$secret")" ]]; then
    # gateway-g3auto secret does not exist
    # maybe we just need to sync secrets from the file system
    if [[ -f "${secretsFolder}/creds.json" ]]; then
        gen3 secrets sync "setup gateway indexd creds in gateway-g3auto"
        return $?
    else
      mkdir -p "$secretsFolder"
    fi
  else
    # already configured
    return 0
  fi

  # Check if the `gateway` indexd user has been configured
  local gatewayIndexdPassword
  if ! gatewayIndexdPassword="$(jq -e -r .indexd.user_db.gateway < "$(gen3_secrets_folder)/creds.json" 2> /dev/null)" \
    || [[ -z "$gatewayIndexdPassword" && "$gatewayIndexdPassword" == null ]]; then
    gatewayIndexdPassword="$(gen3 random)"
    cp "$(gen3_secrets_folder)/creds.json" "$(gen3_secrets_folder)/creds.json.bak"
    jq -r --arg password "$gatewayIndexdPassword" '.indexd.user_db.gateway=$password' < "$(gen3_secrets_folder)/creds.json.bak" > "$(gen3_secrets_folder)/creds.json"
    /bin/rm $(gen3_secrets_folder)/creds.json.bak
  fi
  jq -r -n --arg password "$gatewayIndexdPassword"  --arg b64 "$(echo -n "gateway:$gatewayIndexdPassword" | base64)" '.indexdUser="gateway" | .indexdPassword=$password | .base64Authz=$b64' > "$secretsFolder/creds.json"
  # make it easy for nginx to get the Authorization header ...
  jq -r .base64Authz < "$secretsFolder/creds.json" > "$secretsFolder/base64Authz.txt"
  gen3 secrets sync 'setup gateway indexd creds in gateway-g3auto'
  # get the gateway user into the indexd userdb
  gen3 job run indexd-userdb
}

#current_namespace=$(g3kubectl config view -o jsonpath={.contexts[].context.namespace})
current_namespace=$(gen3 db namespace)

if g3k_manifest_lookup .versions.indexd 2> /dev/null; then
  setup_indexd_gateway
fi

scriptDir="${GEN3_HOME}/kube/services/revproxy"
declare -a confFileList=()
confFileList+=("--from-file" "$scriptDir/gen3.nginx.conf/README.md")

# load priority confs first (who need to fallback on later confs)

# add new nginx conf to route ga4gh access requests to fence instead of indexd
if isServiceVersionGreaterOrEqual "fence" "5.5.0" "2021.10"; then
  filePath="$scriptDir/gen3.nginx.conf/fence-service-ga4gh.conf"
  if [[ -f "$filePath" ]]; then
    echo "$filePath being added to nginx conf file list b/c fence >= 5.4.0 or 2021.10"
    confFileList+=("--from-file" "$filePath")
  fi
fi

for name in $(g3kubectl get services -o json | jq -r '.items[] | .metadata.name'); do
  filePath="$scriptDir/gen3.nginx.conf/${name}.conf"

  if [[ $name == "portal-service" || $name == "frontend-framework-service" ]]; then
    FRONTEND_ROOT=$(g3kubectl get configmap manifest-global --output=jsonpath='{.data.frontend_root}')
    if [[ $FRONTEND_ROOT == "gen3ff" ]]; then
      #echo "setup gen3ff as root frontend service"
      filePath="$scriptDir/gen3.nginx.conf/gen3ff-as-root/${name}.conf"
    else
      #echo "setup windmill as root frontend service"
      filePath="$scriptDir/gen3.nginx.conf/portal-as-root/${name}.conf"
    fi
  fi

  #echo "$filePath"
  if [[ -f "$filePath" ]]; then
    #echo "$filePath exists in $BASHPID!"
    confFileList+=("--from-file" "$filePath")
    #echo "${confFileList[@]}"
  fi
done

if g3kubectl get namespace argo > /dev/null 2>&1;
then
  for argo in $(g3kubectl get services -n argo -o jsonpath='{.items[*].metadata.name}');
  do
    filePath="$scriptDir/gen3.nginx.conf/${argo}.conf"
    if [[ -f "$filePath" ]]; then
      confFileList+=("--from-file" "$filePath")
    fi
  done
fi

if g3kubectl get namespace argocd > /dev/null 2>&1;
then
    filePath="$scriptDir/gen3.nginx.conf/argocd-server.conf"
    if [[ -f "$filePath" ]]; then
      confFileList+=("--from-file" "$filePath")
    fi
fi

if g3kubectl get namespace monitoring > /dev/null 2>&1;
then
    filePath="$scriptDir/gen3.nginx.conf/prometheus-server.conf"
    if [[ -f "$filePath" ]]; then
      confFileList+=("--from-file" "$filePath")
    fi
fi

if g3kubectl get namespace kubecost > /dev/null 2>&1;
then
    filePath="$scriptDir/gen3.nginx.conf/kubecost-service.conf"
    if [[ -f "$filePath" ]]; then
      confFileList+=("--from-file" "$filePath")
    fi
fi

# #echo "${confFileList[@]}" $BASHPID
# if [[ $current_namespace == "default" ]]; then
#   if g3kubectl get namespace grafana > /dev/null 2>&1; then
#     for grafana in $(g3kubectl get services -n grafana -o jsonpath='{.items[*].metadata.name}');
#     do
#       filePath="$scriptDir/gen3.nginx.conf/${grafana}.conf"
#       touch "${XDG_RUNTIME_DIR}/${grafana}.conf"
#       tmpCredsFile="${XDG_RUNTIME_DIR}/${grafana}.conf"
#       adminPass=$(g3kubectl get secrets grafana-admin -o json |jq .data.credentials -r |base64 -d)
#       adminCred=$(echo -n "admin:${adminPass}" | base64 --wrap=0)
#       sed "s/CREDS/${adminCred}/" ${filePath} > ${tmpCredsFile}
#       if [[ -f "${tmpCredsFile}" ]]; then
#         confFileList+=("--from-file" "${tmpCredsFile}")
#       fi
#       #rm -f ${tmpCredsFile}
#     done
#   fi
# fi

if g3k_manifest_lookup .global.document_url  > /dev/null 2>&1; then
  documentUrl="$(g3k_manifest_lookup .global.document_url)"
  if [[ "$documentUrl" != null ]]; then
    filePath="$scriptDir/gen3.nginx.conf/documentation-site/documentation-site.conf"
    confFileList+=("--from-file" "$filePath")
  fi
fi
#
# Funny hook to load the portal-workspace-parent nginx config
#
portalApp="$(g3k_manifest_lookup .global.portal_app)"
if [[ "GEN3-WORKSPACE-PARENT" == "$portalApp" ]]; then
  filePath="$scriptDir/gen3.nginx.conf/portal-workspace-parent.conf"
  confFileList+=("--from-file" "$filePath")
fi

[[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets
gen3 update_config revproxy-nginx-conf "${scriptDir}/nginx.conf"
gen3 update_config logrotate-nginx-conf "${scriptDir}/logrotate-nginx.conf"
gen3 update_config revproxy-helper-js "${scriptDir}/helpers.js"

if g3kubectl get configmap revproxy-nginx-subconf > /dev/null 2>&1; then
  g3kubectl delete configmap revproxy-nginx-subconf
fi
g3kubectl create configmap revproxy-nginx-subconf "${confFileList[@]}"


gen3 roll revproxy

if ! g3kubectl get services revproxy-service > /dev/null 2>&1; then
  g3kubectl apply -f "$scriptDir/revproxy-service.yaml"
else
  #
  # Do not do this automatically as it will trigger an elb
  # change in existing commons
  #
  gen3_log_info "Ensure the commons DNS references the -elb revproxy which support http proxy protocol"
fi

#
# If set do not actually apply the revproxy service.yaml -
# just process the template and echo the yaml that would
# be set to kubectl without --dry-run.
# Mostly useful for debugging or verifying that some change
# will not re-create the AWS load balancer (and force a DNS change)
#
DRY_RUN=${DRY_RUN:-""}
if [[ "$1" =~ ^-*dry-run ]]; then
  DRY_RUN="--dry-run"
fi

export MORE_ELB_CONFIG=""
#
# DISABLE LOGGING
# TODO: We need to give the controller S3 permissions before we
# can auto-apply S3 logging.  Will have to enable logging by hand util we fix that ...
#
if false \
  && bucketName=$(g3kubectl get configmap global --output=jsonpath='{.data.logs_bucket}') \
  && [[ -n "$bucketName" ]]; then
  MORE_ELB_CONFIG=$(cat - <<EOM
    service.beta.kubernetes.io/aws-load-balancer-access-log-enabled: "true"
    service.beta.kubernetes.io/aws-load-balancer-access-log-emit-interval: "60"
    # The interval for publishing the access logs. You can specify an interval of either 5 or 60 (minutes).
    service.beta.kubernetes.io/aws-load-balancer-access-log-s3-bucket-name: "$bucketName"
    service.beta.kubernetes.io/aws-load-balancer-access-log-s3-bucket-prefix: "logs/lb/revproxy"
EOM
)
fi

#
# Set
#    global.lb_type: "internal"
# in the manifest for internal (behind a VPN) load balancer
#
LB_TYPE=$(g3kubectl get configmap manifest-global --output=jsonpath='{.data.lb_type}')
if [[ "$LB_TYPE" != "internal" ]]; then
  LB_TYPE="public"
else
  #
  # Note - for this to work you also have to tag the eks_private* subnets with:
  #    key: kubernetes.io/role/internal-elb, value: 1
  # https://docs.aws.amazon.com/eks/latest/userguide/load-balancing.html
  #
  MORE_ELB_CONFIG="$(cat - <<EOM
$MORE_ELB_CONFIG
    service.beta.kubernetes.io/aws-load-balancer-internal: "true"
EOM
  )"
fi

export ARN=$(g3kubectl get configmap global --output=jsonpath='{.data.revproxy_arn}')
#
# We do this hacky thing where we toggle between different configurations
# based on the value of the 'revproxy_arn' field of the global configmap
#
# Configure revproxy-service-elb - the main external load balancer service
# which targets the revproxy-deployment:
#   * TARGET_PORT_HTTPS == the load-balancer target for https traffic
#   * TARGET_PORT_HTTP == load-balancer target for http traffic
# Default AWS setup - k8s revproxy-service-elb manifests itself
#  as an AWS ELB that terminates HTTPS requests, and
#  forwards http and https traffic to the
#  revproxy deployment using http proxy protocol.
#
# port 81 == proxy-protocol listener - main service entry

gen3_deploy_revproxy_elb() {
gen3_log_info "Deploying revproxy-service-elb..."
export TARGET_PORT_HTTPS=81
# port 82 == proxy-protocol listener - redirects to https
export TARGET_PORT_HTTP=82

if [[ "$ARN" == "GCP" ]]; then
  # port 443 - https listener - main service entry
  export TARGET_PORT_HTTPS=443
  # port 83 - http listener - redirects to https
  export TARGET_PORT_HTTP=83
elif [[ "$ARN" == "ONPREM" ]]; then
  # port 80 - http listener - main service entry
  export TARGET_PORT_HTTPS=80
  # port 83 - http listener - redirects to https
  export TARGET_PORT_HTTP=83
elif [[ ! "$ARN" =~ ^arn ]]; then
  gen3_log_warn "global configmap not configured with TLS certificate ARN"
fi

if [[ -z "$DRY_RUN" ]]; then
  envsubst <$scriptDir/revproxy-service-elb.yaml | g3kubectl apply -f -
else
  gen3_log_info "DRY RUN"
  envsubst <$scriptDir/revproxy-service-elb.yaml
  gen3_log_info "DRY RUN"
fi
}
# Don't automatically apply this right now
#kubectl apply -f $scriptDir/revproxy-service.yaml

if [ "$deployELB" = true ]; then
  gen3_deploy_revproxy_elb
fi
