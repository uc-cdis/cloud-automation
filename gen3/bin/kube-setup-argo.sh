#!/bin/bash
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"
gen3_load "gen3/lib/kube-setup-init"


ctx="$(g3kubectl config current-context)"
ctxNamespace="$(g3kubectl config view -ojson | jq -r ".contexts | map(select(.name==\"$ctx\")) | .[0] | .context.namespace")"


function setup_argo_buckets {
  local accountNumber
  local environment
  local policyFile="$XDG_RUNTIME_DIR/policy_$$.json"
  

  if ! accountNumber="$(aws sts get-caller-identity --output text --query 'Account')"; then
    gen3_log_err "could not determine account numer"
    return 1
  fi
  if ! environment="$(g3kubectl get configmap manifest-global -o json | jq -r .data.environment)"; then
    gen3_log_err "could not determine environment from manifest-global - bailing out of argo setup"
    return 1
  fi


  # try to come up with a unique but composable bucket name
  bucketName="gen3-argo-${accountNumber}-${environment//_/-}"
  userName="gen3-argo-${environment//_/-}-user"
  if ! secret="$(g3kubectl get secret argo-s3-creds -n argo 2> /dev/null)"; then
    gen3_log_info "setting up bucket $bucketName"
    if g3k_config_lookup '.argo."s3-bucket"'; then
      bucketName=$(g3k_config_lookup '.argo."s3-bucket"')
      gen3_log_info "Using S3 bucket found in manifest: ${bucketName}"
    fi
    cat > "$policyFile" <<EOF
{
   "Version":"2012-10-17",
   "Statement":[
      {
         "Effect":"Allow",
         "Action":[
            "s3:PutObject",
            "s3:GetObject"
         ],
         "Resource":"arn:aws:s3:::$bucketName/*"
      }
   ]
}
EOF
    if aws s3 ls --page-size 1 "s3://${bucketName}" > /dev/null 2>&1; then
      gen3_log_info "${bucketName} s3 bucket already exists"
      # continue on ...
    elif ! aws s3 mb "s3://${bucketName}"; then
      gen3_log_err "failed to create bucket ${bucketName}"
    fi


    gen3_log_info "Creating IAM user ${userName}"
    if ! aws iam get-user --user-name ${userName} > /dev/null 2>&1; then 
      aws iam create-user --user-name ${userName}
      aws iam put-user-policy --user-name ${userName} --policy-name argo-bucket-policy --policy-document file://$policyFile
    else 
      gen3_log_info "IAM user ${userName} already exits.."
    fi 

    secret=$(aws iam create-access-key --user-name ${userName})
    if ! g3kubectl get namespace argo > /dev/null 2>&1; then 
      gen3_log_info "Creating argo namespace"
      g3kubectl create namespace argo
      g3kubectl label namespace argo app=argo
      g3kubectl create rolebinding argo-admin --clusterrole=admin --serviceaccount=argo:default -n argo
    fi

    gen3_log_info "Creating s3 creds secret in argo namespace"
    g3kubectl create secret -n argo generic argo-s3-creds --from-literal=AccessKeyId=$(echo $secret  | jq -r .AccessKey.AccessKeyId) --from-literal=SecretAccessKey=$(echo $secret  | jq -r .AccessKey.SecretAccessKey) --from-literal=bucketname=${bucketName}
  else 
    gen3_log_info "Argo S3 setup already completed" 
  fi
}

function setup_argo_db() {
  if ! secret="$(g3kubectl get secret argo-db-creds -n argo 2> /dev/null)"; then
    gen3_log_info "Setting up argo db persistence"
    gen3 db setup argo || true
    dbCreds=$(gen3 secrets decode argo-g3auto dbcreds.json)
    g3kubectl create secret -n argo generic argo-db-creds --from-literal=db_host=$(echo $dbCreds  | jq -r .db_host) --from-literal=db_username=$(echo $dbCreds  | jq -r .db_username) --from-literal=db_password=$(echo $dbCreds  | jq -r .db_password) --from-literal=db_database=$(echo $dbCreds  | jq -r .db_database)
  else 
    gen3_log_info "Argo DB setup already completed"
  fi
}

# only do this if we are running in the default namespace
if [[ "$ctxNamespace" == "default" || "$ctxNamespace" == "null" ]]; then
  setup_argo_buckets
  setup_argo_db
  if (! helm status argo -n argo > /dev/null 2>&1 )  || [[ "$1" == "--force" ]]; then
    DBHOST=$(kubectl get secrets -n argo argo-db-creds -o json | jq -r .data.db_host | base64 -d)
    DBNAME=$(kubectl get secrets -n argo argo-db-creds -o json | jq -r .data.db_database | base64 -d)
    BUCKET=$(kubectl get secrets -n argo argo-s3-creds -o json | jq -r .data.bucketname | base64 -d)
    valuesFile="$XDG_RUNTIME_DIR/values_$$.yaml"
    valuesTemplate="${GEN3_HOME}/kube/services/argo/values.yaml"

    g3k_kv_filter $valuesTemplate GEN3_ARGO_BUCKET "${BUCKET}" GEN3_ARGO_DB_HOST "${DBHOST}" GEN3_ARGO_DB_NAME "${DBNAME}" > ${valuesFile}
    
    helm repo add argo https://argoproj.github.io/argo-helm --force-update 2> >(grep -v 'This is insecure' >&2)
    helm repo update 2> >(grep -v 'This is insecure' >&2)
    helm upgrade --install argo argo/argo-workflows -n argo -f ${valuesFile}
  else
    gen3_log_info "kube-setup-argo exiting - argo already deployed, use --force to redeploy"
  fi
else
  gen3_log_info "kube-setup-argo exiting - only deploys from default namespace"
fi
