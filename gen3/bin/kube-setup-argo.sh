#!/bin/bash
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"
gen3_load "gen3/lib/kube-setup-init"

override_namespace=false
force=false

for arg in "${@}"; do
  if [ "$arg" == "--override-namespace" ]; then
    override_namespace=true
  elif [ "$arg" == "--force" ]; then
    force=true
  else 
    #Print usage info and exit
    gen3_log_info "Usage: gen3 kube-setup-argo [--override-namespace] [--force]"
    exit 1
  fi
done

ctx="$(g3kubectl config current-context)"
ctxNamespace="$(g3kubectl config view -ojson | jq -r ".contexts | map(select(.name==\"$ctx\")) | .[0] | .context.namespace")"

argo_namespace=$(g3k_config_lookup '.argo_namespace' $(g3k_manifest_init)/$(g3k_hostname)/manifests/argo/argo.json)

function setup_argo_buckets {
  local accountNumber
  local environment
  local policyFile="$XDG_RUNTIME_DIR/policy_$$.json"
  local bucketLifecyclePolicyFile="$XDG_RUNTIME_DIR/bucket_lifecycle_policy_$$.json"


  if ! accountNumber="$(aws sts get-caller-identity --output text --query 'Account')"; then
    gen3_log_err "could not determine account numer"
    return 1
  fi
  if ! environment="$(g3k_environment)"; then
    gen3_log_err "could not determine environment from manifest-global - bailing out of argo setup"
    return 1
  fi

  # try to come up with a unique but composable bucket name
  bucketName="gen3-argo-${accountNumber}-${environment//_/-}"
  nameSpace="$(gen3 db namespace)"
  roleName="gen3-argo-${environment//_/-}-role"
  bucketPolicy="argo-bucket-policy-${nameSpace}"
  internalBucketPolicy="argo-internal-bucket-policy-${nameSpace}"
  if [[ ! -z $(g3k_config_lookup '."downloadable-s3-bucket"' $(g3k_manifest_init)/$(g3k_hostname)/manifests/argo/argo.json) || ! -z $(g3k_config_lookup '.argo."downloadable-s3-bucket"') ]]; then
    if [[ ! -z $(g3k_config_lookup '."downloadable-s3-bucket"' $(g3k_manifest_init)/$(g3k_hostname)/manifests/argo/argo.json) ]]; then
      gen3_log_info "Using S3 bucket found in manifest: ${bucketName}"
      bucketName=$(g3k_config_lookup '."downloadable-s3-bucket"' $(g3k_manifest_init)/$(g3k_hostname)/manifests/argo/argo.json)
    else
      gen3_log_info "Using S3 bucket found in manifest: ${bucketName}"
      bucketName=$(g3k_config_lookup '.argo."downloadable-s3-bucket"')
    fi
  fi
  if [[ ! -z $(g3k_config_lookup '."internal-s3-bucket"' $(g3k_manifest_init)/$(g3k_hostname)/manifests/argo/argo.json) || ! -z $(g3k_config_lookup '.argo."internal-s3-bucket"') ]]; then
    if [[ ! -z $(g3k_config_lookup '."internal-s3-bucket"' $(g3k_manifest_init)/$(g3k_hostname)/manifests/argo/argo.json) ]]; then
      gen3_log_info "Using S3 bucket found in manifest: ${bucketName}"
      internalBucketName=$(g3k_config_lookup '."internal-s3-bucket"' $(g3k_manifest_init)/$(g3k_hostname)/manifests/argo/argo.json)
    else
      gen3_log_info "Using S3 bucket found in manifest: ${bucketName}"
      internalBucketName=$(g3k_config_lookup '.argo."internal-s3-bucket"')
    fi
    gen3_log_info "Using internal S3 bucket found in manifest: ${internalBucketName}"
    local internalBucketPolicyFile="$XDG_RUNTIME_DIR/internal_bucket_policy_$$.json"
    cat > "$internalBucketPolicyFile" <<EOF
{
   "Version":"2012-10-17",
   "Statement":[
      {
         "Effect":"Allow",
         "Action":[
            "s3:PutObject",
            "s3:GetObject"
         ],
         "Resource":"arn:aws:s3:::$internalBucketName/*"
      },
      {
         "Action": [
            "s3:List*",
            "s3:Get*"
         ],
         "Effect": "Allow",
         "Resource": [
            "arn:aws:s3:::$internalBucketName"
         ]
      }
   ]
}
EOF
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
      },
      {
         "Action": [
            "s3:List*",
            "s3:Get*"
         ],
         "Effect": "Allow",
         "Resource": [
            "arn:aws:s3:::$bucketName"
         ]
      }
   ]
}
EOF
    cat > "$bucketLifecyclePolicyFile" <<EOF
{
  "Rules": [
    {
      "ID": "Store objects in Glacier after 4 months",
      "Prefix": "",
      "Status": "Enabled",
      "Transition": {
        "Days": 120,
        "StorageClass": "GLACIER"
      }
    }
  ]
}
EOF

# Create a cluster role with specific permissions for Argo
cat <<EOF | g3kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argo-cluster-role
rules:
- apiGroups: [""]
  resources: ["pods", "pods/exec", "pods/log"]
  verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
- apiGroups: ["argoproj.io"]
  resources: [
    "applications",
    "applicationsets",
    "appprojects",
    "clusterworkflowtemplates",
    "cronworkflows",
    "eventbus",
    "eventsources",
    "sensors",
    "workflowartifactgctasks",
    "workfloweventbindings",
    "workflows",
    "workflowtaskresults",
    "workflowtasksets",
    "workflowtemplates"
  ]
  verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
EOF

  # Create argo SA within the current namespace
  gen3_log_info "Creating argo SA in the current namespace"
  g3kubectl create sa argo -n $nameSpace | true
  if aws s3 ls --page-size 1 "s3://${bucketName}" > /dev/null 2>&1; then
    gen3_log_info "${bucketName} s3 bucket already exists"
    # continue on ...
  elif ! aws s3 mb "s3://${bucketName}"; then
    gen3_log_err "failed to create bucket ${bucketName}"
  fi
  if ! g3kubectl get namespace argo > /dev/null 2>&1; then
    gen3_log_info "Creating argo namespace"
    g3kubectl create namespace argo || true
    g3kubectl label namespace argo app=argo || true
    # Grant access within the argo namespace to the default SA in the argo namespace
    g3kubectl create rolebinding argo-rolebinding --clusterrole=argo-cluster-role --serviceaccount=argo:default -n $argo_namespace || true
  fi
  gen3_log_info "Creating IAM role ${roleName}"
  if aws iam get-role --role-name "${roleName}" > /dev/null 2>&1; then
      gen3_log_info "IAM role ${roleName} already exists.."
      roleArn=$(aws iam get-role --role-name "${roleName}" --query 'Role.Arn' --output text)
      gen3_log_info "Role annotate"
      g3kubectl annotate serviceaccount default eks.amazonaws.com/role-arn=${roleArn} --overwrite -n $argo_namespace
      g3kubectl annotate serviceaccount argo-argo-workflows-server eks.amazonaws.com/role-arn=${roleArn} --overwrite -n $argo_namespace
      g3kubectl annotate serviceaccount argo eks.amazonaws.com/role-arn=${roleArn} --overwrite -n $nameSpace
  else
        gen3 awsrole create $roleName argo $nameSpace -all_namespaces
        roleArn=$(aws iam get-role --role-name "${roleName}" --query 'Role.Arn' --output text)
        g3kubectl annotate serviceaccount default eks.amazonaws.com/role-arn=${roleArn} -n $argo_namespace
        g3kubectl annotate serviceaccount argo-argo-workflows-server eks.amazonaws.com/role-arn=${roleArn} -n $argo_namespace
  fi

  # Grant access within the current namespace to the argo SA in the current namespace
  g3kubectl create rolebinding argo-rolebinding --clusterrole=argo-cluster-role --serviceaccount=$nameSpace:argo -n $nameSpace || true
  aws iam put-role-policy --role-name ${roleName} --policy-name ${bucketPolicy} --policy-document file://$policyFile || true
  if [[ -z $internalBucketName ]]; then
    aws iam put-role-policy --role-name ${roleName} --policy-name ${internalBucketPolicy} --policy-document file://$internalBucketPolicyFile || true
  fi

  # Create a secret for the slack webhook
  alarm_webhook=$(g3kubectl get cm global -o yaml | yq .data.slack_alarm_webhook | tr -d '"')

  if [ -z "$alarm_webhook" ]; then
    gen3_log_err "Please set a slack_alarm_webhook in the 'global' configmap. This is needed to alert for failed workflows."
    exit 1
  fi

  g3kubectl -n argo delete secret slack-webhook-secret
  g3kubectl -n argo create secret generic "slack-webhook-secret" --from-literal=SLACK_WEBHOOK_URL=$alarm_webhook


  ## if new bucket then do the following
  # Get the aws keys from secret
  # Create and attach lifecycle policy
  # Set bucket policies
  # Update secret to have new bucket

  gen3_log_info "Creating bucket lifecycle policy"
  aws s3api put-bucket-lifecycle --bucket ${bucketName} --lifecycle-configuration file://$bucketLifecyclePolicyFile

  # Always update the policy, in case manifest buckets change
  aws iam put-role-policy --role-name ${roleName} --policy-name ${bucketPolicy} --policy-document file://$policyFile
  if [[ ! -z $internalBucketPolicyFile ]]; then
    aws iam put-role-policy --role-name ${roleName} --policy-name ${internalBucketPolicy} --policy-document file://$internalBucketPolicyFile
  fi
  if [[ ! -z $(g3k_config_lookup '.indexd_admin_user' $(g3k_manifest_init)/$(g3k_hostname)/manifests/argo/argo.json) || ! -z $(g3k_config_lookup '.argo.indexd_admin_user') ]]; then
    if [[ ! -z $(g3k_config_lookup '.indexd_admin_user' $(g3k_manifest_init)/$(g3k_hostname)/manifests/argo/argo.json) ]]; then
      indexd_admin_user=$(g3k_config_lookup '.indexd_admin_user' $(g3k_manifest_init)/$(g3k_hostname)/manifests/argo/argo.json)
    else
      indexd_admin_user=$(g3k_config_lookup '.argo.indexd_admin_user')
    fi
    gen3_log_info "Creating secret for indexd admin user creds using $indexd_admin_user user"
    for serviceName in indexd; do
      secretName="${serviceName}-creds"
      # Only delete if secret is found to prevent early exits
      if [[ ! -z $(g3kubectl get secrets -n $argo_namespace | grep $secretName) ]]; then
        g3kubectl delete secret "$secretName" -n $argo_namespace > /dev/null 2>&1
      fi
    done
    sleep 1  # I think delete is async - give backend a second to finish
    indexdFencePassword=$(cat $(gen3_secrets_folder)/creds.json | jq -r .indexd.user_db.$indexd_admin_user)
    g3kubectl create secret generic "indexd-creds" --from-literal=user=$indexd_admin_user --from-literal=password=$indexdFencePassword -n $argo_namespace
  fi
}

function setup_argo_db() {
  if ! secret="$(g3kubectl get secret argo-db-creds -n $argo_namespace 2> /dev/null)"; then
    gen3_log_info "Setting up argo db persistence"
    gen3 db setup argo || true
    dbCreds=$(gen3 secrets decode argo-g3auto dbcreds.json)
    g3kubectl create secret -n $argo_namespace generic argo-db-creds --from-literal=db_host=$(echo $dbCreds  | jq -r .db_host) --from-literal=db_username=$(echo $dbCreds  | jq -r .db_username) --from-literal=db_password=$(echo $dbCreds  | jq -r .db_password) --from-literal=db_database=$(echo $dbCreds  | jq -r .db_database)
  else
    gen3_log_info "Argo DB setup already completed"
  fi
}

function setup_argo_template_secret() {
  gen3_log_info "Started the template secret process"
  downloadable_bucket_name=$(g3k_config_lookup '."downloadable-s3-bucket"' $(g3k_manifest_init)/$(g3k_hostname)/manifests/argo/argo.json)
  # Check if the secret already exists
    if [[ ! -z $(g3kubectl get secret argo-template-values-secret -n $argo_namespace) ]]; then
      gen3_log_info "Argo template values secret already exists, assuming it's stale and deleting"
      g3kubectl delete secret argo-template-values-secret -n $argo_namespace
    fi
  gen3_log_info "Creating argo template values secret"
  g3kubectl create secret generic argo-template-values-secret --from-literal=DOWNLOADABLE_BUCKET=$downloadable_bucket_name -n $argo_namespace 
}

setup_argo_buckets
# only do this if we are running in the default namespace
if [[ "$ctxNamespace" == "default" || "$ctxNamespace" == "null" || "$override_namespace" == true ]]; then
  setup_argo_db
  setup_argo_template_secret 
  if (! helm status argo -n $argo_namespace > /dev/null 2>&1 )  || [[ "$force" == true ]]; then
    DBHOST=$(kubectl get secrets -n $argo_namespace argo-db-creds -o json | jq -r .data.db_host | base64 -d)
    DBNAME=$(kubectl get secrets -n $argo_namespace argo-db-creds -o json | jq -r .data.db_database | base64 -d)
    if [[ -z $internalBucketName ]]; then
      BUCKET=$bucketName
    else
      BUCKET=$internalBucketName
    fi

    valuesFile="$XDG_RUNTIME_DIR/values_$$.yaml"
    valuesTemplate="${GEN3_HOME}/kube/services/argo/values.yaml"

    g3k_kv_filter $valuesTemplate GEN3_ARGO_BUCKET "${BUCKET}" GEN3_ARGO_DB_HOST "${DBHOST}" GEN3_ARGO_DB_NAME "${DBNAME}" > ${valuesFile}

    helm repo add argo https://argoproj.github.io/argo-helm --force-update 2> >(grep -v 'This is insecure' >&2)
    helm repo update 2> >(grep -v 'This is insecure' >&2)
    helm upgrade --install argo argo/argo-workflows -n $argo_namespace -f ${valuesFile} --version 0.29.1
  else
    gen3_log_info "kube-setup-argo exiting - argo already deployed, use --force to redeploy"
  fi
else
  gen3_log_info "kube-setup-argo exiting - only deploys from default namespace"
fi