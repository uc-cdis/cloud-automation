#!/bin/bash
#
# Deploy aws-es-proxy into existing commons
# https://github.com/abutaha/aws-es-proxy
# 


source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

# Deploy Datadog with argocd if flag is set in the manifest path
manifestPath=$(g3k_manifest_path)
es7="$(jq -r ".[\"global\"][\"es7\"]" < "$manifestPath" | tr '[:upper:]' '[:lower:]')"

[[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets

envname="$(gen3 api environment)"

sa_name="esproxy-sa"
if ! kubectl get serviceaccount $sa_name 2>&1; then
  kubectl create serviceaccount $sa_name
fi

role_arn=$(aws iam get-role --role-name "${vpc_name}-esproxy-sa" | jq .Role.Arn | tr -d '"')

if [[ "$role_arn" != "" ]]; then
  kubectl annotate sa "$sa_name" eks.amazonaws.com/role-arn="$role_arn"
  deploy_path="${GEN3_HOME}/kube/services/aws-es-proxy/aws-es-proxy-deploy-irsa.yaml"
else
  gen3_log_info "No role named '${vpc_name}-esproxy-sa' found. Falling back to using aws-es-proxy secret"
  deploy_path="${GEN3_HOME}/kube/services/aws-es-proxy/aws-es-proxy-deploy.yaml"
fi


if [ "$es7" = true ]; then
  if ES_ENDPOINT="$(aws es describe-elasticsearch-domains --domain-names "${envname}"-gen3-metadata-2 --query "DomainStatusList[*].Endpoints" --output text)" \
      && [[ -n "${ES_ENDPOINT}" && -n "${envname}" ]]; then
    g3k_manifest_filter "$deploy_path" "" GEN3_ES_ENDPOINT "${ES_ENDPOINT}" | g3kubectl apply -f - 
    g3kubectl apply -f "${GEN3_HOME}/kube/services/aws-es-proxy/aws-es-proxy-priority-class.yaml" 
    g3kubectl apply -f "${GEN3_HOME}/kube/services/aws-es-proxy/aws-es-proxy-service.yaml"
    gen3_log_info "kube-setup-aws-es-proxy" "The aws-es-proxy service has been deployed onto the k8s cluster."
  else
    #
    # probably running in jenkins or job environment
    # try to make sure network policy labels are up to date
    #
    gen3_log_info "kube-setup-aws-es-proxy" "Not deploying aws-es-proxy, no endpoint to hook it up."
    gen3 kube-setup-networkpolicy service aws-es-proxy
    g3kubectl patch deployment "aws-es-proxy-deployment" -p  '{"spec":{"template":{"metadata":{"labels":{"netvpc":"yes"}}}}}' || true
  fi
else
  if ES_ENDPOINT="$(aws es describe-elasticsearch-domains --domain-names "${envname}"-gen3-metadata --query "DomainStatusList[*].Endpoints" --output text)" \
      && [[ -n "${ES_ENDPOINT}" && -n "${envname}" ]]; then
    g3k_manifest_filter "$deploy_path" "" GEN3_ES_ENDPOINT "${ES_ENDPOINT}" | g3kubectl apply -f -
    g3kubectl apply -f "${GEN3_HOME}/kube/services/aws-es-proxy/aws-es-proxy-service.yaml"
    gen3_log_info "kube-setup-aws-es-proxy" "The aws-es-proxy service has been deployed onto the k8s cluster."
  else
    #
    # probably running in jenkins or job environment
    # try to make sure network policy labels are up to date
    #
    gen3_log_info "kube-setup-aws-es-proxy" "Not deploying aws-es-proxy, no endpoint to hook it up."
    gen3 kube-setup-networkpolicy service aws-es-proxy
    g3kubectl patch deployment "aws-es-proxy-deployment" -p  '{"spec":{"template":{"metadata":{"labels":{"netvpc":"yes"}}}}}' || true
  fi
fi
gen3 job cron es-garbage '@daily'
