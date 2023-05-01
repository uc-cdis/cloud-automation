#!/bin/bash
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"
gen3_load "gen3/lib/kube-setup-init"

accountID=$(aws sts get-caller-identity --output text --query 'Account')
awsRegion=$(aws configure get region)

gen3_setup_kubecost_infrastructure() {
  gen3 workon default "${vpc_name}__kubecost"
  gen3 cd
  echo "vpc_name=\"$vpc_name\"" > config.tfvars
  if [[ ! -z "$curBucketCreated" ]]; then
   echo "cur_s3_bucket=\"$curBucket\"" >> config.tfvars
  fi
  if [[ ! -z "$reportBucketCreated" ]]; then
    echo "reports_s3_bucket=\"$reportBucket\"" >> config.tfvars
  fi
  gen3 tfplan 2>&1
  gen3 tfapply 2>&1
}

gen3_destroy_kubecost_infrastructure() {
  gen3 workon default "${vpc_name}__kubecost"
  gen3 tfplan --destroy 2>&1
  gen3 tfapply 2>&1
  gen3 cd
  cd ..
  rm -rf "${vpc_name}__kubecost"
}

gen3_setup_kubecost_service_account() {
  # Kubecost SA
  roleName="$vpc_name-kubecost-user"
  saName="kubecost-cost-analyzer"
  gen3 awsrole create "$roleName" "$saName" "kubecost" || return 1
  aws iam attach-role-policy --role-name "$roleName" --policy-arn "arn:aws:iam::$accountID:policy/$vpc_name-Kubecost-CUR-policy" 1>&2
  #gen3 awsrole sa-annotate "$saName" "$roleName" "kubecost"
  kubectl delete sa -n kubecost $saName
  # SA for reports
  reportsRoleName="$vpc_name-opencost-report-role"
  reportsSaName="reports-service-account"
  gen3 awsrole create "$reportsRoleName" "$reportsSaName" "kubecost" || return 1
  aws iam attach-role-policy --role-name "$reportsRoleName" --policy-arn "arn:aws:iam::$accountID:policy/$vpc_name-Kubecost-report-policy" 1>&2
  gen3 awsrole sa-annotate "$reportsSaName" "$reportsRoleName" "kubecost" 
}

gen3_delete_kubecost_service_account() {
  aws iam detach-role-policy --role-name "${vpc_name}-kubecost-user" --policy-arn "arn:aws:iam::$accountID:policy/$vpc_name-Kubecost-CUR-policy" 1>&2
  gen3 workon default "${vpc_name}-kubecost-user_role"
  gen3 tfplan --destroy 2>&1
  gen3 tfapply 2>&1
}

gen3_delete_kubecost() {
  gen3_delete_kubecost_service_account
  gen3_destroy_kubecost_infrastructure
  helm delete kubecost -n kubecost
}

gen3_kubecost_create_alb() {
  kubectl apply -f "${GEN3_HOME}/kube/services/kubecost/kubecost-alb.yaml" -n kubecost
}

gen3_setup_kubecost() {
  kubectl create namespace kubecost || true
  # If s3 bucket not supplied, create a new one
  if [[ -z $curBucket ]]; then
    curBucket="$vpc_name-kubecost-bucket"
  fi
  # If report bucket not supplied, use the same as cur bucket
  if [[ -z $reportBucket ]]; then
    reportBucket=$curBucket
  fi    
  gen3_setup_kubecost_infrastructure
  aws ec2 create-spot-datafeed-subscription --bucket $curBucket --prefix spot-feed || true
  # Change the SA permissions based on slave/master/standalone
  if [[ -z $(kubectl get sa -n kubecost | grep $vpc_name-kubecost-user) ]]; then
    gen3_setup_kubecost_service_account
  fi
  if (! helm status kubecost -n kubecost > /dev/null 2>&1 )  || [[ ! -z "$FORCE" ]]; then
    valuesFile="$XDG_RUNTIME_DIR/values_$$.yaml"
    valuesTemplate="${GEN3_HOME}/kube/services/kubecost/values.yaml"
    g3k_kv_filter $valuesTemplate KUBECOST_SA "eks.amazonaws.com/role-arn: arn:aws:iam::$accountID:role/gen3_service/$roleName" ATHENA_BUCKET "$curBucket" ATHENA_DATABASE "athenacurcfn_$vpc_name" ATHENA_TABLE "${vpc_name}_cur" AWS_ACCOUNT_ID "$accountID" AWS_REGION "$awsRegion" > $valuesFile
    helm repo add kubecost https://kubecost.github.io/cost-analyzer/ --force-update 2> >(grep -v 'This is insecure' >&2)
    helm repo update 2> >(grep -v 'This is insecure' >&2)
    helm upgrade --install kubecost kubecost/cost-analyzer -n kubecost -f ${valuesFile}
  else
    gen3_log_info "kube-setup-kubecost exiting - kubecost already deployed, use --force true to redeploy"
  fi
  gen3_kubecost_create_alb
}

gen3_setup_reports_cronjob() {
  gen3 job cron opencost-report-argo '0 0 * * 0' BUCKET_NAME $reportBucket
}

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  if [[ -z "$1" || "$1" =~ ^-*help$ ]]; then
    gen3_logs_help
    exit 0
  fi
  command="$1"
  shift
  case "$command" in
    "create")
      for flag in $@; do
        if [[ $# -gt 0 ]]; then
          flag="$1"
          shift
        fi
        case "$flag" in
          "--force")
            if [[ $(echo $1 | tr '[:upper:]' '[:lower:]') == "true" ]]; then
              FORCE=true
            fi
            ;;
          "--cur-bucket")
            curBucket="$1"
            curBucketCreated=true
            ;;
          "--report-bucket")
            reportBucket="$1"
            reportBucketCreated=true
            ;;                        
        esac
      done
      gen3_setup_kubecost "$@" 
      ;;
    "cronjob")
      subcommand=""
      if [[ $# -gt 0 ]]; then
        subcommand="$1"
        shift
      fi
      case "$subcommand" in
        "create")
          for flag in $@; do
            if [[ $# -gt 0 ]]; then
              flag="$1"
              shift
            fi
            case "$flag" in
              "--report-bucket")
                reportBucket="$1"
                ;;
            esac
          done
          if [[ -z $reportBucket ]]; then
            gen3_log_err "Please ensure you set the reportBucket for setting up cronjob without full opencost deployment."
            exit 1
          fi
          gen3_setup_reports_cronjob
          ;;
        *)
          gen3_log_err "gen3_logs" "invalid history subcommand $subcommand - try: gen3 help kube-setup-kubecost"
          ;;
      esac
      ;;
    "delete")
      gen3_delete_kubecost
      ;;
    *)
      gen3_setup_kubecost "$@" 
      ;;
  esac
fi
