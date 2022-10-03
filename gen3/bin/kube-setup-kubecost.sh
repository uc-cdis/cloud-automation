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
  elif [[ $deployment == "master" ]]; then
    echo "slave_account_id=\"$slaveAccountId\"" >> config.tfvars
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
  reportsRoleName="$vpc_name-opencost-report-role"
  reportsSaName="reports-service-account"
  gen3 awsrole create "$reportsRoleName" "$reportsSaName" "kubecost" || return 1
  aws iam attach-role-policy --role-name "$reportsRoleName" --policy-arn "arn:aws:iam::$accountID:policy/$vpc_name-Kubecost-Thanos-policy" 1>&2
  gen3 awsrole sa-annotate "$reportsSaName" "$reportsRoleName" "kubecost" 
}

gen3_delete_kubecost_service_account() {
  aws iam detach-role-policy --role-name "${vpc_name}-kubecost-user" --policy-arn "arn:aws:iam::$accountID:policy/$vpc_name-Kubecost-CUR-policy" 1>&2
  aws iam detach-role-policy --role-name "${vpc_name}-thanos-user" --policy-arn "arn:aws:iam::$accountID:policy/$vpc_name-Kubecost-Thanos-policy" 1>&2 
  gen3 workon default "${vpc_name}-kubecost-user_role"
  gen3 tfplan --destroy 2>&1
  gen3 tfapply 2>&1
  gen3 workon default "${vpc_name}-thanos-user_role"
  gen3 tfplan --destroy 2>&1
  gen3 tfapply 2>&1  
}

gen3_delete_kubecost() {
  gen3_delete_kubecost_service_account
  gen3_destroy_kubecost_infrastructure
  helm delete kubecost -n kubecost
}

gen3_kubecost_create_alb() {
  kubectl apply -f "${GEN3_HOME}/kube/services/kubecost-${deployment}/kubecost-alb.yaml" -n kubecost
}

gen3_setup_kubecost() {
  kubectl create namespace kubecost || true
  gen3_setup_kubecost_infrastructure
  # Change the SA permissions based on slave/master/standalone
  if [[ -z $(kubectl get sa -n kubecost | grep $vpc_name-kubecost-user) ]]; then
    gen3_setup_kubecost_service_account
  fi
  # If master setup and s3 bucket not supplied, set terraform master s3 bucket name for thanos secret
  if [[ -z $s3Bucket ]]; then
    s3Bucket="$vpc_name-kubecost-bucket"
  fi
  if (! helm status kubecost -n kubecost > /dev/null 2>&1 )  || [[ ! -z "$FORCE" ]]; then
    if [[ $deployment == "slave" ]]; then
      valuesFile="$XDG_RUNTIME_DIR/values_$$.yaml"
      valuesTemplate="${GEN3_HOME}/kube/services/kubecost-slave/values.yaml"
      thanosValuesFile="$XDG_RUNTIME_DIR/object-store.yaml"
      thanosValuesTemplate="${GEN3_HOME}/kube/services/kubecost-slave/object-store.yaml"
      thanosValues="${GEN3_HOME}/kube/services/kubecost-slave/values-thanos.yaml"
      g3k_kv_filter $valuesTemplate KUBECOST_TOKEN "${kubecostToken}" KUBECOST_SA "eks.amazonaws.com/role-arn: arn:aws:iam::$accountID:role/gen3_service/$roleName" THANOS_SA "$thanosSaName" ATHENA_BUCKET "s3://$s3Bucket" ATHENA_DATABASE "athenacurcfn_$vpc_name" ATHENA_TABLE "${vpc_name}_cur" AWS_ACCOUNT_ID "$accountID" AWS_REGION "$awsRegion" > $valuesFile
    elif [[ $deployment == "master" ]]; then
      valuesFile="$XDG_RUNTIME_DIR/values_$$.yaml"
      valuesTemplate="${GEN3_HOME}/kube/services/kubecost-master/values.yaml"
      thanosValuesFile="$XDG_RUNTIME_DIR/object-store.yaml"
      thanosValuesTemplate="${GEN3_HOME}/kube/services/kubecost-master/object-store.yaml"
      g3k_kv_filter $valuesTemplate KUBECOST_TOKEN "${kubecostToken}" KUBECOST_SA "eks.amazonaws.com/role-arn: arn:aws:iam::$accountID:role/gen3_service/$roleName" THANOS_SA "$thanosSaName" ATHENA_BUCKET "s3://$s3Bucket" ATHENA_DATABASE "athenacurcfn_$vpc_name" ATHENA_TABLE "${vpc_name}_cur" AWS_ACCOUNT_ID "$accountID" AWS_REGION "$awsRegion"  > $valuesFile
      gen3_kubecost_create_alb
    else
      valuesFile="$XDG_RUNTIME_DIR/values_$$.yaml"
      valuesTemplate="${GEN3_HOME}/kube/services/kubecost-standalone/values.yaml"
      #thanosValuesFile="$XDG_RUNTIME_DIR/object-store.yaml"
      #thanosValuesTemplate="${GEN3_HOME}/kube/services/kubecost-standalone/object-store.yaml"
      g3k_kv_filter $valuesTemplate KUBECOST_TOKEN "${kubecostToken}" KUBECOST_SA "eks.amazonaws.com/role-arn: arn:aws:iam::$accountID:role/gen3_service/$roleName" THANOS_SA "$thanosSaName" ATHENA_BUCKET "s3://$s3Bucket" ATHENA_DATABASE "athenacurcfn_$vpc_name" ATHENA_TABLE "${vpc_name}_cur" AWS_ACCOUNT_ID "$accountID" AWS_REGION "$awsRegion" > $valuesFile
      gen3_kubecost_create_alb
    fi
    #kubectl delete secret -n kubecost kubecost-thanos || true
    #kubectl delete secret -n kubecost thanos || true
    #g3k_kv_filter $thanosValuesTemplate AWS_REGION $awsRegion KUBECOST_S3_BUCKET $s3Bucket > $thanosValuesFile
    #kubectl create secret generic kubecost-thanos -n kubecost --from-file=$thanosValuesFile
    #kubectl create secret generic thanos -n kubecost --from-file=$thanosValuesFile
    # Need to setup thanos config
    gen3 kube-setup-certs
    gen3 kube-setup-prometheus
    g3kubectl delete secret -n kubecost cert-kubecost-cost-analyzer || true
    g3kubectl create secret generic "cert-kubecost-cost-analyzer" "--from-file=tls.crt=$(gen3_secrets_folder)/credentials/kubecost-cost-analyzer-service.crt" "--from-file=tls.key=$(gen3_secrets_folder)/credentials/kubecost-cost-analyzer-service.key" -n kubecost || true
    helm repo add kubecost https://kubecost.github.io/cost-analyzer/ --force-update 2> >(grep -v 'This is insecure' >&2)
    helm repo update 2> >(grep -v 'This is insecure' >&2)
    if [[ -z $disablePrometheus ]]; then
      helm upgrade --install kubecost kubecost/cost-analyzer -n kubecost -f ${valuesFile} 
    else
      helm upgrade --install kubecost kubecost/cost-analyzer -n kubecost -f ${valuesFile}
    fi
  else
    gen3_log_info "kube-setup-kubecost exiting - kubecost already deployed, use --force true to redeploy"
  fi
  gen3_setup_reports_cronjob
}

gen3_setup_reports_cronjob {
  gen3 job cron opencost-report '0 0 * * 0' BUCKET_NAME $s3Bucket
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
              "--slave-account-id")
                slaveAccountId="$1"
                ;;
              "--kubecost-token")
                kubecostToken="$1"
                ;;
              "--force")
                if [[ $(echo $1 | tr '[:upper:]' '[:lower:]') == "true" ]]; then
                  FORCE=true
                fi
                ;;
              "--disable-prometheus")
                if [[ $(echo $1 | tr '[:upper:]' '[:lower:]') == "true" ]]; then
                  disablePrometheus=true
                fi
                ;;
              "--prometheus-namespace")
                prometheusNamespace="$1"
                ;;
              "--prometheus-service")
                prometheusService="$1"
                ;;
            esac
          done
          if [[ -z $slaveAccountId || -z $kubecostToken  ]]; then
            gen3_log_err "Please ensure you set the required flags."
            exit 1
          fi
          if [[ $disablePrometheus == true && -z $prometheusNamespace && -z $prometheusService ]]; then
            gen3_log_err "If you disable prometheus, set the flags for the local prometheus namespace and service name."
            exit 1
          fi
          gen3_setup_kubecost "$@"    
          ;;
        "alb")
          gen3_kubecost_create_alb
          ;;
        *)
          gen3_log_err "gen3_logs" "invalid history subcommand $subcommand - try: gen3 help kube-setup-kubecost"
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
              "--kubecost-token")
                kubecostToken="$1"
                ;;
              "--force")
                if [[ $(echo $1 | tr '[:upper:]' '[:lower:]') == "true" ]]; then
                  FORCE=true
                fi
                ;;
              "--disable-prometheus")
                if [[ $(echo $1 | tr '[:upper:]' '[:lower:]') == "true" ]]; then
                  disablePrometheus=true
                fi
                ;;
              "--prometheus-namespace")
                prometheusNamespace="$1"
                ;;
              "--prometheus-service")
                prometheusService="$1"
                ;;
            esac
          done
          if [[ -z $s3Bucket || -z $kubecostToken ]]; then
            gen3_log_err "Please ensure you set the required flags."
            exit 1
          fi
          if [[ $disablePrometheus == true && -z $prometheusNamespace && -z $prometheusService ]]; then
            gen3_log_err "If you disable prometheus, set the flags for the local prometheus namespace and service name."
            exit 1
          fi
          gen3_setup_kubecost "$@"    
          ;;
        *)
          gen3_log_err "gen3_logs" "invalid history subcommand $subcommand - try: gen3 help kube-setup-kubecost"
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
              "--disable-prometheus")
                if [[ $(echo $1 | tr '[:upper:]' '[:lower:]') == "true" ]]; then
                  disablePrometheus=true
                fi
                ;;
              "--prometheus-namespace")
                prometheusNamespace="$1"
                ;;
              "--prometheus-service")
                prometheusService="$1"
                ;;
            esac
          done
          if [[ -z $kubecostToken ]]; then
            gen3_log_err "Please ensure you set the required flags."
            exit 1
          fi
          if [[ $disablePrometheus == true && -z $prometheusNamespace && -z $prometheusService ]]; then
            gen3_log_err "If you disable prometheus, set the flags for the local prometheus namespace and service name."
            exit 1
          fi
          gen3_setup_kubecost "$@" 
          ;;
        "alb")
          gen3_kubecost_create_alb
          ;;
        *)
          gen3_log_err "gen3_logs" "invalid history subcommand $subcommand - try: gen3 help kube-setup-kubecost"
          ;;
      esac
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
              "--s3-bucket")
                s3Bucket="$1"
                ;;
            esac
          done
          if [[ -z $s3Bucket ]]; then
            gen3_log_err "Please ensure you set the s3Bucket for setting up cronjob without full opencost deployment."
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
      gen3_log_err "gen3_logs" "invalid command $command"
      gen3_kubecost_help
      ;;
  esac
fi
