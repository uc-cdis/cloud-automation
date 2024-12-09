#!/bin/bash
#
# Deploy aws-es-proxy into existing commons
# https://github.com/abutaha/aws-es-proxy
#


source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

manifestPath=$(g3k_manifest_path)
es7="$(jq -r ".[\"global\"][\"es7\"]" < "$manifestPath" | tr '[:upper:]' '[:lower:]')"
esDomain="$(jq -r ".[\"global\"][\"esDomain\"]" < "$manifestPath" | tr '[:upper:]' '[:lower:]')"
envname="$(gen3 api environment)"

[[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets

if g3kubectl get secrets/aws-es-proxy > /dev/null 2>&1; then
  if [ "$esDomain" != "null" ]; then
    if ES_ENDPOINT="$(aws es describe-elasticsearch-domains --domain-names "${esDomain}"  --query "DomainStatusList[*].Endpoints" --output text)" \
        && [[ -n "${ES_ENDPOINT}" && -n "${esDomain}" ]]; then
      gen3 roll aws-es-proxy GEN3_ES_ENDPOINT "${ES_ENDPOINT}"
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
  elif [ "$es7" = false ]; then
    if ES_ENDPOINT="$(aws es describe-elasticsearch-domains --domain-names "${envname}"-gen3-metadata --query "DomainStatusList[*].Endpoints" --output text)" \
        && [[ -n "${ES_ENDPOINT}" && -n "${envname}" ]]; then
      gen3 roll aws-es-proxy GEN3_ES_ENDPOINT "${ES_ENDPOINT}"
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
    if ES_ENDPOINT="$(aws es describe-elasticsearch-domains --domain-names "${envname}"-gen3-metadata-2 --query "DomainStatusList[*].Endpoints" --output text)" \
        && [[ -n "${ES_ENDPOINT}" && -n "${envname}" ]]; then
      gen3 roll aws-es-proxy GEN3_ES_ENDPOINT "${ES_ENDPOINT}"
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
  fi
  gen3 job cron es-garbage '@daily'
else
    gen3_log_info "kube-setup-aws-es-proxy" "No secret detected, attempting IRSA setup"
    deploy=true

    # Let's pre-calculate all the info we need about the cluster, so we can just pass it on later
    if [ "$esDomain" != "null" ] && [ -n "$esDomain" ]; then
      ES_ENDPOINT="$(aws es describe-elasticsearch-domains --domain-names "${esDomain}" --query "DomainStatusList[*].Endpoints" --output text)"
      ES_ARN="$(aws es describe-elasticsearch-domains --domain-names "${esDomain}" --query "DomainStatusList[*].ARN" --output text)"
    elif [ "$es7" = true ]; then
      if [ -n "$envname" ]; then
        ES_ENDPOINT="$(aws es describe-elasticsearch-domains --domain-names "${envname}"-gen3-metadata-2 --query "DomainStatusList[*].Endpoints" --output text)" 
        ES_ARN="$(aws es describe-elasticsearch-domains --domain-names "${envname}"-gen3-metadata-2 --query "DomainStatusList[*].ARN" --output text)"
      else
        deploy=false
      fi
    else
      if [ -n "$envname" ]; then
        ES_ENDPOINT="$(aws es describe-elasticsearch-domains --domain-names "${envname}"-gen3-metadata --query "DomainStatusList[*].Endpoints" --output text)" 
        ES_ARN="$(aws es describe-elasticsearch-domains --domain-names "${envname}"-gen3-metadata --query "DomainStatusList[*].ARN" --output text)"
      else
        deploy=false
      fi
    fi
     # Let's only do setup stuff if we're going to want to deploy... otherwise, we take the CI env actions
    if [ "$deploy" = "true" ]; then
      # Put that ARN into a template we get from terraform
      policyjson=$(cat <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "es:*",
      "Effect": "Allow",
      "Resource": [
        "$ES_ARN",
        "${ES_ARN}/*"
      ]
    }
  ]
}
POLICY
)

      # Creating the role
      roleName="$(gen3 api safe-name es-access)"
      saName="esproxy-sa"
      policyName="$(gen3 api safe-name es-access-policy)"

      gen3 awsrole create "$roleName" "$saName"
      policyArn=$(gen3_aws_run aws iam list-policies --query "Policies[?PolicyName=='$policyName'].Arn" --output text)

      if [ -n "$policyArn" ]; then
        echo "No need to create policy, it already exists" 
      else
        gen3_aws_run aws iam create-policy --policy-name "$policyName" --policy-document "$policyjson" --description "Allow access to the given ElasticSearch cluster"
      fi 
      
      # Now we need some info on the policy, so we can attach the role and the plicy
      policyArn=$(gen3_aws_run aws iam list-policies --query "Policies[?PolicyName=='$policyName'].Arn" --output text)
      gen3 awsrole attach-policy "${policyArn}" --role-name "${roleName}" --force-aws-cli || exit 1

      g3k_manifest_filter "${GEN3_HOME}/kube/services/aws-es-proxy/aws-es-proxy-deploy-irsa.yaml" "" GEN3_ES_ENDPOINT "${ES_ENDPOINT}" | g3kubectl apply -f - 
      # Then we have to do the whole setup... just copy and modify from above
      if [ "$es7" = true ]; then
        g3kubectl apply -f "${GEN3_HOME}/kube/services/aws-es-proxy/aws-es-proxy-priority-class.yaml"
      fi
      g3kubectl apply -f "${GEN3_HOME}/kube/services/aws-es-proxy/aws-es-proxy-service.yaml"
      gen3_log_info "kube-setup-aws-es-proxy" "The aws-es-proxy service has been deployed onto the k8s cluster."
    else
      gen3_log_info "kube-setup-aws-es-proxy" "Not deploying aws-es-proxy, no endpoint to hook it up."
      gen3 kube-setup-networkpolicy service aws-es-proxy
      g3kubectl patch deployment "aws-es-proxy-deployment" -p  '{"spec":{"template":{"metadata":{"labels":{"netvpc":"yes"}}}}}' || true
    fi
  fi
