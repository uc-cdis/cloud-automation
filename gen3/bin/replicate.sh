#!/bin/bash


source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

#
# Some helpers for managing multiple databases
# on each of a set of db servers.
#

# lib -----------------------------------

# Creates
gen3_replicate_create_manifest() {
  local bucket=$1
  local destination=$2
  if [[ -f $WORKSPACE/tempKeyFile ]]; then
    gen3_log_info "previous key file found. Deleting"
    rm $WORKSPACE/tempKeyFile
  fi
  aws s3api list-objects --bucket "$bucket" --query 'Contents[].{Key: Key}' | jq -r '.[].Key' >> "$WORKSPACE/tempKeyFile"
  if [[ -f $WORKSPACE/manifest.csv ]]; then
    rm $WORKSPACE/manifest.csv
  fi
  while read line; do
    echo "$bucket,$line" >> $WORKSPACE/manifest.csv
  done<$WORKSPACE/tempKeyFile
  rm $WORKSPACE/tempKeyFile
  if [[ ! -z $3 ]]; then
    gen3_aws_run aws s3 cp $WORKSPACE/manifest.csv s3://"$destination" --profile $3
  else
    gen3_aws_run aws s3 cp $WORKSPACE/manifest.csv s3://"$destination"
  fi
  rm $WORKSPACE/manifest.csv
}

# function to create job
## creates job and returns command to check job status after completed
gen3_replicate_create_job() {
  local source=$1
  local destination=$2
  if [[ ! -z $3 ]]; then
    local profile=$3
    local etag=$(gen3_aws_run aws s3api list-objects --profile $profile --bucket $2 --output json --query '{Name: Contents[].{Key: ETag}}' --prefix manifest.csv | jq -r .Name[].Key | sed -e 's/"//g')
    local OPERATION='{"S3PutObjectCopy": {"TargetResource": "arn:aws:s3:::'$destination'"}}'
    local MANIFEST='{"Spec": {"Format": "S3BatchOperations_CSV_20180820","Fields": ["Bucket","Key"]},"Location": {"ObjectArn": "arn:aws:s3:::'$destination'/manifest.csv","ETag": "'$etag'"}}'
    local REPORT='{"Bucket": "arn:aws:s3:::'$destination'","Format": "Report_CSV_20180820","Enabled": true,"Prefix": "reports/copy-with-replace-metadata","ReportScope": "AllTasks"}'
    local roleArn=$(gen3_aws_run aws iam get-role --profile $profile --role-name batch-operations-role | jq -r .Role.Arn)
    local accountId=$(gen3_aws_run aws iam get-role --profile $profile --role-name batch-operations-role | jq -r .Role.Arn | cut -d : -f 5)
    status=$(gen3_aws_run aws s3control create-job --profile $profile --account-id $accountId --manifest "${MANIFEST//$'\n'}" --operation "${OPERATION//$'\n'/}" --report "${REPORT//$'\n'}" --priority 10 --role-arn $roleArn  --region us-east-1 --description "Copy with Replace Metadata" --no-confirmation-required | jq -r .JobId)
  else
    local etag=$(gen3_aws_run aws s3api list-objects --bucket $2 --output json --query '{Name: Contents[].{Key: ETag}}' --prefix manifest.csv | jq -r .Name[].Key | sed -e 's/"//g')
    local OPERATION='{"S3PutObjectCopy": {"TargetResource": "arn:aws:s3:::'$destination'"}}'
    local MANIFEST='{"Spec": {"Format": "S3BatchOperations_CSV_20180820","Fields": ["Bucket","Key"]},"Location": {"ObjectArn": "arn:aws:s3:::'$destination'/manifest.csv","ETag": "'$etag'"}}'
    local REPORT='{"Bucket": "arn:aws:s3:::'$destination'","Format": "Report_CSV_20180820","Enabled": true,"Prefix": "reports/copy-with-replace-metadata","ReportScope": "AllTasks"}'
    local roleArn=$(gen3_aws_run aws iam get-role --role-name batch-operations-role | jq -r .Role.Arn)
    local accountId=$(gen3_aws_run aws iam get-role --role-name batch-operations-role | jq -r .Role.Arn |cut -d : -f 5)
    status=$(gen3_aws_run aws s3control create-job --account-id "$accountId" --manifest "${MANIFEST//$'\n'}" --operation "${OPERATION//$'\n'/}" --report "${REPORT//$'\n'}" --priority 10 --role-arn $roleArn --client-request-token "$(uuidgen)" --region us-east-1 --description "Copy with Replace Metadata" --no-confirmation-required | jq -r .JobId)
  fi
  echo $status
}

# function to check job status
gen3_replicate_status() {
  local jobId=$1
  counter=0
  ## fix to account for other profile
  if [[ ! -z $2 ]]; then
    local profile=$2
    local accountId=$(gen3_aws_run aws iam get-role --role-name batch-operations-role --profile $profile --region us-east-1 | jq -r .Role.Arn | cut -d : -f 5)
    local status=$(gen3_aws_run aws s3control describe-job --account-id $accountId --job-id $jobId --profile $profile --region us-east-1 | jq -r .Job.Status)
    while [[ $status != 'Complete' ]] || [[ $counter > 90 ]]; do
      gen3_log_info "Waiting for job to complete. Current status $status"
      local status=$(gen3_aws_run aws s3control describe-job --account-id $accountId --job-id $jobId --profile $profile --region us-east-1 | jq -r .Job.Status)
      let counter=counter+1
      sleep 10
    done
  else
    local accountId=$(gen3_aws_run aws iam get-role --role-name batch-operations-role --region us-east-1 | jq -r .Role.Arn | cut -d : -f 5)
    local status=$(gen3_aws_run aws s3control describe-job --account-id $accountId --job-id $jobId --region us-east-1 | jq -r .Job.Status)
    while [[ $status != 'Complete' ]] || [[ $counter > 90 ]]; do
      gen3_log_info "Waiting for job to complete. Current status $status"
      local status=$(gen3_aws_run aws s3control describe-job --account-id $accountId --job-id $jobId --region us-east-1 | jq -r .Job.Status)
      let counter=counter+1
      sleep 10      
    done
  fi
  if [[ $counter > 90 ]]; then
    gen3_log_err "Job $jobId timed out trying to run. The job will clean up and if the job is still in progress it's permissions will be removed and will become broken."
  fi
  echo $status
}



####### IAM part

# function to check if role/policy exists
## if no role call create role
## if no policy create policy, if policy modify policy to support new endpoints

gen3_replicate_init() {
  local source=$1
  local destination=$2
  if [[ ! -z $3 ]]; then
    local profile=$3
    if [[ -z $(gen3_aws_run aws iam list-roles --profile $profile | jq -r .Roles[].RoleName | grep batch-operations-role) ]]; then
      gen3_log_info "Creating batch operations role in destination account"
      local trustRelationship="{\"Version\": \"2012-10-17\",\"Statement\": [{\"Effect\": \"Allow\",\"Principal\": {\"Service\": \"batchoperations.s3.amazonaws.com\"},\"Action\": \"sts:AssumeRole\"}]}"
      gen3_aws_run aws iam create-role --role-name batch-operations-role --assume-role-policy-document "$trustRelationship"  --profile $profile
    fi
    local destinationAccountId=$(gen3_aws_run aws iam get-role --role-name batch-operations-role --profile "$profile" | jq -r .Role.Arn | cut -d : -f 5)
    local destinationRolePolicy="{\"Version\": \"2012-10-17\",\"Statement\": [{\"Sid\": \"AllowBatchOperationsDestinationObjectCOPY\",\"Effect\": \"Allow\",\"Action\": [\"s3:PutObject\",\"s3:PutObjectVersionAcl\",\"s3:PutObjectAcl\",\"s3:PutObjectVersionTagging\",\"s3:PutObjectTagging\",\"s3:GetObject\",\"s3:GetObjectVersion\",\"s3:GetObjectAcl\",\"s3:GetObjectTagging\",\"s3:GetObjectVersionAcl\",\"s3:GetObjectVersionTagging\"],\"Resource\": [\"arn:aws:s3:::$source/*\",\"arn:aws:s3:::$destinaion/*\"]}]}"
# need to only make a joint policy if there was a policy previously.
    gen3_log_info "Checking for old policies and modfying bucket policy to add batch operations policy"
    resetPolicy=$(gen3_aws_run aws s3api get-bucket-policy --bucket $source | jq -r .Policy )
    local oldPolicy=$(gen3_aws_run aws s3api get-bucket-policy --bucket $source | jq -r .Policy | jq -r .Statement[] )
    local newPolicy=$(echo "{\"Sid\": \"AllowBatchOperationsSourceManfiestRead\",\"Effect\": \"Allow\",\"Principal\": {\"AWS\": [\"arn:aws:iam::$destinationAccountId:role/batch-operations-role\"]},\"Action\": [\"s3:GetObject\",\"s3:GetObjectVersion\"],\"Resource\": \"arn:aws:s3:::$source/*\"}" |jq -r .)
    if [[ -z $oldPolicy ]]; then
      local bucketPolicy='{"Version": "2012-10-17", "Statement": ['$newPolicy']}'
    else
      gen3_log_info "Found old bucket policy. Modifying for new policy $oldPolicy"
      local bucketPolicy='{"Version": "2012-10-17", "Statement": ['$oldPolicy','$newPolicy']}'
    fi
    # sleep to allow role to fully generate for policy
    sleep 5
    gen3_aws_run aws s3api put-bucket-policy --bucket $source --policy "$bucketPolicy"
    if [[ ! -z $(gen3_aws_run aws iam list-role-policies --role-name batch-operations-role --profile "$profile" | jq -r .PolicyNames[]) ]]; then
      gen3_log_info "Old policy exists. Removing in favor of new policy"
      gen3_aws_run aws iam delete-role-policy --role-name batch-operations-role --policy-name batch-operations-policy --profile $profile
    fi
    local policy="{\"Version\": \"2012-10-17\", \"Statement\": [ { \"Action\": [ \"s3:PutObject\", \"s3:PutObjectAcl\", \"s3:PutObjectTagging\" ], \"Effect\": \"Allow\", \"Resource\": \"arn:aws:s3:::$destination/*\" }, { \"Action\": [ \"s3:GetObject\", \"s3:GetObjectAcl\", \"s3:GetObjectTagging\" ], \"Effect\": \"Allow\", \"Resource\": \"arn:aws:s3:::$source/*\" }, { \"Effect\": \"Allow\", \"Action\": [ \"s3:GetObject\", \"s3:GetObjectVersion\", \"s3:GetBucketLocation\" ], \"Resource\": [ \"arn:aws:s3:::$destination/*\" ] }, { \"Effect\": \"Allow\", \"Action\": [ \"s3:PutObject\", \"s3:GetBucketLocation\" ], \"Resource\": [ \"arn:aws:s3:::$destination/*\" ] }    ]}"
    gen3_aws_run aws iam put-role-policy --role-name batch-operations-role --policy-name batch-operations-policy --policy-document "${policy//$'\n'}" --profile $profile
  else
    if [[ -z $(gen3_aws_run aws iam list-roles | jq -r .Roles[].RoleName | grep batch-operations-role) ]]; then
      gen3_log_info "Creating batch-operations role"
      local trustRelationship="{\"Version\": \"2012-10-17\",\"Statement\": [{\"Effect\": \"Allow\",\"Principal\": {\"Service\": \"batchoperations.s3.amazonaws.com\"},\"Action\": \"sts:AssumeRole\"}]}"
      gen3_aws_run aws iam create-role --role-name batch-operations-role --assume-role-policy-document "${trustRelationship//$'\n'}"
    fi
    if [[ ! -z $(gen3_aws_run aws iam list-role-policies --role-name batch-operations-role | jq -r .PolicyNames[]) ]]; then
      gen3_log_info "Old policy exists. Modifying for new policy"
      gen3_aws_run aws iam delete-role-policy --role-name batch-operations-role --policy-name batch-operations-policy
    fi
    local policy="{\"Version\": \"2012-10-17\", \"Statement\": [ { \"Action\": [ \"s3:PutObject\", \"s3:PutObjectAcl\", \"s3:PutObjectTagging\" ], \"Effect\": \"Allow\", \"Resource\": \"arn:aws:s3:::$destination/*\" }, { \"Action\": [ \"s3:GetObject\", \"s3:GetObjectAcl\", \"s3:GetObjectTagging\" ], \"Effect\": \"Allow\", \"Resource\": \"arn:aws:s3:::$source/*\" }, { \"Effect\": \"Allow\", \"Action\": [ \"s3:GetObject\", \"s3:GetObjectVersion\", \"s3:GetBucketLocation\" ], \"Resource\": [ \"arn:aws:s3:::$destination/*\" ] }, { \"Effect\": \"Allow\", \"Action\": [ \"s3:PutObject\", \"s3:GetBucketLocation\" ], \"Resource\": [ \"arn:aws:s3:::$destination/*\" ] }    ]}"
    gen3_aws_run aws iam put-role-policy --role-name batch-operations-role --policy-name batch-operations-policy --policy-document "${policy//$'\n'}"
    # sleep to allow role to fully generate for policy
    sleep 20
  fi
}

gen3_replication() {
  gen3_replicate_init $@
  gen3_replicate_create_manifest $@
  status=$(gen3_replicate_create_job $@)
  gen3_replicate_status $status $3
  gen3_replicate_cleanup $@
}

gen3_replicate_cleanup() {
  source=$1
  destination=$2
  gen3_log_info "Cleaning up roles/policies"
  if [[ ! -z $3 ]]; then
    local profile=$3
    gen3_log_info "Deleting role policy"
    gen3_aws_run aws iam delete-role-policy --role-name batch-operations-role --policy-name batch-operations-policy --profile $profile
    gen3_log_info "Deleting role"
    gen3_aws_run aws iam delete-role --role-name batch-operations-role --profile $profile
    if [[ ! -z $resetPolicy ]]; then
      gen3_log_info "Old bucket policy found. Reverting back to it."
      gen3_aws_run aws s3api put-bucket-policy --bucket $source --policy "$resetPolicy"
    else
      gen3_log_info "Deleting bucket policy"
      gen3_aws_run aws s3api delete-bucket-policy --bucket $source
    fi
  else
    gen3_log_info "Deleting role policy"
    gen3_aws_run aws iam delete-role-policy --role-name batch-operations-role --policy-name batch-operations-policy
    gen3_log_info "Deleting role"
    gen3_aws_run aws iam delete-role --role-name batch-operations-role
  fi
}

gen3_replicate_help() {
  gen3 help replicate
}

command="$1"
shift
case "$command" in
  'bucket')
    gen3_replication "$@"
    ;;
  'status')
    gen3_replicate_status "$@"
    ;;
  'help')
    gen3_replicate_help "$@"
    ;;
  *)
    gen3_replicate_help
    ;;
esac
exit $?