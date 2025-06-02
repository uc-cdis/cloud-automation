source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

setup_funnel_infra() {
  gen3_log_info "Setting up funnel"
  helm repo add ohsu https://ohsu-comp-bio.github.io/helm-charts
  helm repo update ohsu

  secretsFolder="$(gen3_secrets_folder)/g3auto/gen3workflow"
  if [[ ! -f "$secretsFolder/funnel.conf" ]]; then
    mkdir -p "$secretsFolder"
    # NOTE: to update once Funnel supports per-user bucket credentials
    cat - > "$secretsFolder/funnel.conf" <<EOM
AmazonS3:
  Key: PLACEHOLDER
  Secret: PLACEHOLDER
  Disabled: false

Kubernetes:
  Bucket: PLACEHOLDER
  Region: us-east-1

Logger:
  # Logging levels: debug, info, error
  Level: info
EOM
  fi

  namespace="$(gen3 db namespace)"
  version="$(g3k_manifest_lookup .versions.funnel)"
  if [ "$version" == "latest" ]; then
    helm upgrade --install funnel ohsu/funnel --namespace $namespace --values "$secretsFolder/funnel.conf"
  else
    helm upgrade --install funnel ohsu/funnel --namespace $namespace --values "$secretsFolder/funnel.conf" --version $version
  fi
}

setup_gen3_workflow_infra() {
  gen3_log_info "Setting up gen3-workflow"

  # grant the gen3-workflow service account the AWS access the service needs
  saName="gen3-workflow-sa"
  gen3_log_info Setting up service account $saName
  policy=$( cat <<EOM
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ManageS3Buckets",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:PutEncryptionConfiguration",
        "s3:PutBucketPolicy",
        "s3:PutLifecycleConfiguration"
      ],
      "Resource": [
        "arn:aws:s3:::gen3wf-*",
        "arn:aws:s3:::gen3wf-*/*"
      ]
    },
    {
      "Sid": "ManageKMS",
      "Effect": "Allow",
      "Action": [
          "kms:CreateKey",
          "kms:GenerateDataKey",
          "kms:CreateAlias",
          "kms:DescribeKey",
          "kms:TagResource"
      ],
      "Resource": "*"
    }
  ]
}
EOM
)
  roleName="$(gen3 api safe-name $saName)"
  gen3 awsrole create $roleName $saName
  policyName="$(gen3 api safe-name gen3-workflow-policy)"
  policyInfo="$(gen3_aws_run aws iam create-policy --policy-name "$policyName" --policy-document "$policy" --description "Gen3-Workflow service access")"
  if [ -n "$policyInfo" ]; then
    policyArn="$(jq -e -r '.["Policy"].Arn' <<< "$policyInfo")" || { gen3_log_err "Cannot get 'Policy.Arn' from output: $policyInfo"; return 1; }
  else
    gen3_log_info "Unable to create policy '$policyName'. Assume it already exists and create a new version to update the permissions..."
    policyArn="$(gen3_aws_run aws iam list-policies --query "Policies[?PolicyName=='$policyName'].Arn" --output text)"

    # there can only be up to 5 versions, so delete old versions (except the current default one)
    versions="$(gen3_aws_run aws iam list-policy-versions --policy-arn $policyArn | jq -r '.Versions[] | select(.IsDefaultVersion != true) | .VersionId')"
    versions=(${versions}) # string to array
    for v in "${versions[@]}"; do
        gen3_log_info "Deleting old version '$v'"
        gen3_aws_run aws iam delete-policy-version --policy-arn $policyArn --version-id $v
    done

    # create the new version
    gen3_aws_run aws iam create-policy-version --policy-arn "$policyArn" --policy-document "$policy" --set-as-default
  fi
  gen3_log_info "Attaching policy '${policyName}' to role '${roleName}'"
  gen3 awsrole attach-policy ${policyArn} --role-name ${roleName} --force-aws-cli || exit 1

  # create the gen3-workflow config file if it doesn't already exist
  # Note: `gen3_db_service_setup` doesn't allow '-' in the database name, so the db and secret
  # name are 'gen3workflow' and not 'gen3-workflow'. If we need a db later, we'll run `gen3 db
  # setup gen3workflow`
  if g3kubectl describe secret gen3workflow-g3auto > /dev/null 2>&1; then
    gen3_log_info "gen3workflow-g3auto secret already configured"
    return 0
  fi
  if [[ -n "$JENKINS_HOME" || ! -f "$(gen3_secrets_folder)/creds.json" ]]; then
    gen3_log_err "skipping config file setup in non-adminvm environment"
    return 0
  fi
  secretsFolder="$(gen3_secrets_folder)/g3auto/gen3workflow"
  if [[ ! -f "$secretsFolder/gen3-workflow-config.yaml" ]]; then
    mkdir -p "$secretsFolder"
    manifestPath="$(g3k_manifest_path)"
    hostname="$(g3k_config_lookup ".global.hostname" "$manifestPath")"
    cat - > "$secretsFolder/gen3-workflow-config.yaml" <<EOM
HOSTNAME: $hostname
APP_DEBUG: false
EOM
  gen3 secrets sync 'setup gen3workflow-g3auto secrets'
  fi
}

if g3k_manifest_lookup .versions.funnel 2> /dev/null; then
  if ! setup_funnel_infra; then
    gen3_log_err "kube-setup-gen3-workflow bailing out - failed to set up funnel infrastructure"
    exit 1
  fi
  gen3_log_info "The funnel service has been deployed onto the kubernetes cluster."
else
  gen3_log_warn "not deploying funnel - no manifest entry for .versions.funnel. The gen3-workflow service may not work!"
fi

if ! setup_gen3_workflow_infra; then
  gen3_log_err "kube-setup-gen3-workflow bailing out - failed to set up gen3-workflow infrastructure"
  exit 1
fi
gen3 roll gen3-workflow
g3kubectl apply -f "${GEN3_HOME}/kube/services/gen3-workflow/gen3-workflow-service.yaml"
gen3_log_info "The gen3-workflow service has been deployed onto the kubernetes cluster."
