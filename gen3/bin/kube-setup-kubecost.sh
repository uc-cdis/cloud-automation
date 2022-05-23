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
  if [[ $deployment == "slave" ]]; then
    echo "cur_s3_bucket=\"$s3Bucket\"" >> config.tfvars
    echo "parent_account_id=\"$parentAccountId\"" >> config.tfvars
    echo "parent_vpc=\"$parentVPC\"" >> config.tfvars
    echo "child_vpc=\"$childVPC\"" >> config.tfvars
  elif [[ $deployment == "master" ]]; then
    echo "slave_account_id=\"$slaveAccountId\"" >> config.tfvars
    echo "slave_kubecost_role=\"$slaveKubecostRole\"" >> config.tfvars
  fi
  gen3 tfplan 2>&1
  gen3 tfapply 2>&1
}

gen3_setup_kubecost_service_account() {
  # Kubecost SA
  roleName="$vpc_name-kubecost-user"
  saName="kubecost-service-account"
  gen3 awsrole create "$roleName" "$saName" "kubecost" || return 1
  aws iam attach-role-policy --role-name "$roleName" --policy-arn "arn:aws:iam::$accountID:policy/$vpc_name-Kubecost-CUR-policy" 1>&2
  gen3 awsrole sa-annotate "$saName" "$roleName" "kubecost"

  # Thanos SA
  thanosRoleName="$vpc_name-thanos-user"
  thanosSaName="thanos-service-account"
  gen3 awsrole create "$thanosRoleName" "$thanosSaName" "kubecost" || return 1
  aws iam attach-role-policy --role-name "$thanosRoleName" --policy-arn "arn:aws:iam::$accountID:policy/$vpc_name-Kubecost-Thanos-policy" 1>&2
  gen3 awsrole sa-annotate "$thanosSaName" "$thanosRoleName" "kubecost"  
}

gen3_setup_kubecost() {
  gen3_setup_kubecost_infrastructure
  # Change the SA permissions based on slave/master/standalone
  if [[ -z $(kubectl get sa -n kubecost | grep $vpc_name-kubecost-user) ]]; then
    gen3_setup_kubecost_service_account
  fi
  if (! helm status kubecost -n kubecost > /dev/null 2>&1 )  || [[ ! -z "$FORCE" ]]; then
    
    if [[ $deployment == "slave" ]]; then
      valuesFile="$XDG_RUNTIME_DIR/values_$$.yaml"
      valuesTemplate="${GEN3_HOME}/kube/services/kubecost-slave/values.yaml"
      thanosValuesFile="$XDG_RUNTIME_DIR/object-store.yaml"
      thanosValuesTemplate="${GEN3_HOME}/kube/services/kubecost-slave/object-store.yaml"
      g3k_kv_filter $valuesTemplate KUBECOST_TOKEN "${kubecostToken}" KUBECOST_SA "eks.amazonaws.com/role-arn: arn:aws:iam::$accountID:role/$roleName" THANOS_SA "eks.amazonaws.com/role-arn: arn:aws:iam::$accountID:role/$thanosRoleName" ATHENA_BUCKET "aws-athena-query-results-$accountID-$awsRegion" ATHENA_DATABASE "athenacurcfn_$vpc_name" ATHENA_TABLE "$vpc_name-cur" AWS_ACCOUNT_ID "$accountID" AWS_REGION "$awsRegion" > $valuesFile
    elif [[ $deployment == "master" ]]; then
      valuesFile="$XDG_RUNTIME_DIR/values_$$.yaml"
      valuesTemplate="${GEN3_HOME}/kube/services/kubecost-master/values.yaml"
      thanosValuesFile="$XDG_RUNTIME_DIR/object-store.yaml"
      thanosValuesTemplate="${GEN3_HOME}/kube/services/kubecost-master/object-store.yaml"
      g3k_kv_filter $valuesTemplate KUBECOST_TOKEN "${kubecostToken}" KUBECOST_SA "eks.amazonaws.com/role-arn: arn:aws:iam::$accountID:role/$roleName" THANOS_SA "eks.amazonaws.com/role-arn: arn:aws:iam::$accountID:role/$thanosRoleName" ATHENA_BUCKET "aws-athena-query-results-$accountID-$awsRegion" ATHENA_DATABASE "athenacurcfn_$vpc_name" ATHENA_TABLE "$vpc_name-cur" AWS_ACCOUNT_ID "$accountID" AWS_REGION "$awsRegion" KUBECOST_SLAVE_ALB "$slaveALB" > $valuesFile
    else
      valuesFile="$XDG_RUNTIME_DIR/values_$$.yaml"
      valuesTemplate="${GEN3_HOME}/kube/services/kubecost-master/values.yaml"
      thanosValuesFile="$XDG_RUNTIME_DIR/object-store.yaml"
      thanosValuesTemplate="${GEN3_HOME}/kube/services/kubecost-master/object-store.yaml"
      g3k_kv_filter $valuesTemplate KUBECOST_TOKEN "${kubecostToken}" KUBECOST_SA "{}" > $valuesFile
    fi
    # If master setup and s3 bucket not supplied, set terraform master s3 bucket name for thanos secret
    if [[ -z $s3Bucket ]]; then
      s3Bucket="$vpc_name-kubecost-bucket"
    fi
    g3k_kv_filter $thanosValuesTemplate AWS_REGION $awsRegion KUBECOST_S3_BUCKET $s3Bucket > $thanosValuesFile
    # Need to setup thanos config
    if [[ ! -z $(kubectl get secrets -n kubecost | grep kubecost-thanos) ]]; then
      kubectl delete secret -n kubecost kubecost-thanos
    fi
    kubectl create secret generic kubecost-thanos -n kubecost --from-file=$thanosValuesFile

    helm repo add kubecost https://kubecost.github.io/cost-analyzer/ --force-update 2> >(grep -v 'This is insecure' >&2)
    helm repo update 2> >(grep -v 'This is insecure' >&2)
    helm upgrade --install kubecost kubecost/cost-analyzer -n kubecost -f ${valuesFile}
  else
    gen3_log_info "kube-setup-kubecost exiting - kubecost already deployed, use --force true to redeploy"
  fi
}

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  if [[ -z "$1" || "$1" =~ ^-*help$ ]]; then
    gen3_logs_help
    exit 0
  fi
  command="$1"
  shift
  case "$command" in
    "master")
      deployment="master"
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
              "--slave-kubecost-role")
                slaveKubecostRole="$1"
                ;;
              "--slave-account-id")
                slaveAccountId="$1"
                ;;
              "--kubecost-token")
                kubecostToken="$1"
                ;;
              "--slave-alb")
                slaveALB="$1"
                ;;
              "--force")
                if [[ $(echo $1 | tr '[:upper:]' '[:lower:]') == "true" ]]; then
                  FORCE=true
                fi
                ;;
            esac
          done
          if [[ -z $slaveKubecostRole || -z $slaveAccountId || -z $kubecostToken || -z $slaveALB ]]; then
            gen3_log_err "Please ensure you set the required flags."
            exit 1
          fi
          gen3_setup_kubecost "$@"    
          ;;
        "delete")
          echo "Will be implemented"
          ;;
        *)
          gen3_log_err "gen3_logs" "invalid history subcommand $subcommand - try: gen3 help logs"
          ;;
      esac
      ;;
    "slave")
      deployment="slave"
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
              "--s3-bucket")
                s3Bucket="$1"
                ;;
              "--parent-account-id")
                parentAccountId="$1"
                ;;
              "--kubecost-token")
                kubecostToken="$1"
                ;;
              "--parent-vpc")
                parentVPC="$1"
                ;;
              "--child-vpc")
                childVPC="$1"
                ;;
              "--force")
                if [[ $(echo $1 | tr '[:upper:]' '[:lower:]') == "true" ]]; then
                  FORCE=true
                fi
                ;;
            esac
          done
          if [[ -z $s3Bucket || -z $parentAccountId || -z $kubecostToken || -z $parentVPC || -z $childVPC ]]; then
            gen3_log_err "Please ensure you set the required flags."
            exit 1
          fi
          gen3_setup_kubecost "$@"    
          ;;
        "delete")
          echo "Will be implemented"
          ;;
        *)
          gen3_log_err "gen3_logs" "invalid history subcommand $subcommand - try: gen3 help logs"
          ;;
      esac
      ;;
    "standalone")
      deployment="standalone"
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
              "--kubecost-token")
                kubecostToken="$1"
                ;;
              "--force")
                if [[ $(echo $1 | tr '[:upper:]' '[:lower:]') == "true" ]]; then
                  FORCE=true
                fi
                ;;
            esac
          done
          if [[ -z $kubecostToken ]]; then
            gen3_log_err "Please ensure you set the required flags."
            exit 1
          fi
          gen3_setup_kubecost "$@" 
          ;;
        "delete")
          echo "Will be implemented"
          ;;
        *)
          gen3_log_err "gen3_logs" "invalid history subcommand $subcommand - try: gen3 help logs"
          ;;
      esac
      ;;
    *)
      gen3_log_err "gen3_logs" "invalid command $command"
      gen3_logs_help
      ;;
  esac
fi
