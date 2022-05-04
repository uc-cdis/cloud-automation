#!/bin/bash
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"
gen3_load "gen3/lib/kube-setup-init"

if [[ -z $1 ]]; then
  gen3_log_err "Please provide token and use this like gen3 kube-setup-kubecost <kubecost token>"
else
  kubecostToken="$1"
fi
if [[ $2 == "setupSA" ]]; then
  setupSA=true
fi
ctx="$(g3kubectl config current-context)"
ctxNamespace="$(g3kubectl config view -ojson | jq -r ".contexts | map(select(.name==\"$ctx\")) | .[0] | .context.namespace")"
accountID=$(aws sts get-caller-identity --output text --query 'Account')

setup_kubecost_infrastructure() {
  gen3 workon default "${vpc_name}__kubecost"
  gen3 cd
  echo "vpc_name=$vpc_name" > config.tfvars
  gen3 tfplan 2>&1
  gen3 tfapply 2>&1
}

setup_kubecost_service_account() {
  roleName="emalinowskiv1-kubecost-user"
  saName="kubecost-service-account"
  gen3 awsrole create "$roleName" "$saName" "kubecost" || return 1
  aws iam attach-role-policy --role-name "$roleName" --policy-arn "arn:aws:iam::$accountID:policy/$vpc_name-Kubecost-CUR-policy" 1>&2
  gen3 awsrole sa-annotate "$saName" "$roleName" "kubecost"
}

# only do this if we are running in the default namespace
if [[ "$ctxNamespace" == "default" || "$ctxNamespace" == "null" ]]; then
  setup_kubecost_infrastructure
  if $setupSA; then
    setup_kubecost_service_account
  fi
  if (! helm status kubecost -n kubecost > /dev/null 2>&1 )  || [[ "$1" == "--force" ]]; then

    ## Need to find vars to add to this, probably kubecost token, and SA info
    valuesFile="$XDG_RUNTIME_DIR/values_$$.yaml"
    valuesTemplate="${GEN3_HOME}/kube/services/kubecost/values.yaml"
    if $setupSA; then
      g3k_kv_filter $valuesTemplate KUBECOST_TOKEN "${kubecostToken}" KUBECOST_SA "eks.amazonaws.com/role-arn: arn:aws:iam::$accountID:role/$roleName"
    else
      g3k_kv_filter $valuesTemplate KUBECOST_TOKEN "${kubecostToken}" KUBECOST_SA "{}"
    fi

    helm repo add kubecost https://kubecost.github.io/cost-analyzer/ --force-update 2> >(grep -v 'This is insecure' >&2)
    helm repo update 2> >(grep -v 'This is insecure' >&2)
    helm upgrade --install kubecost kubecost/cost-analyzer -n kubecost -f ${valuesFile}
  else
    gen3_log_info "kube-setup-kubecost exiting - kubecost already deployed, use --force to redeploy"
  fi
else
  gen3_log_info "kube-setup-kubecost exiting - only deploys from default namespace"
fi
