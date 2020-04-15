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
  if [[ -f /home/emalinowskiv1/tempKeyFile ]]; then
    gen3_log_info "previous key file found. Delet"
    rm tempKeyFile
  fi
  echo $bucket
  aws s3api list-objects --bucket "$bucket" --query 'Contents[].{Key: Key}' | jq -r '.[].Key' >> "/home/emalinowskiv1/tempKeyFile"
  if [[ -f /home/emalinowskiv1/manifest.csv ]]; then
    rm /home/emalinowskiv1/manifest.csv
  fi
  while read line; do
    echo "$bucket,$line"
    echo "$bucket,$line" >> /home/emalinowskiv1/manifest.csv
  done</home/emalinowskiv1/tempKeyFile
  rm /home/emalinowskiv1/tempKeyFile
  if [[ ! -z $3 ]]; then
    gen3_aws_run aws s3 cp /home/emalinowskiv1/manifest.csv s3://"$destination" --profile $3
  else
    gen3_aws_run aws s3 cp /home/emalinowskiv1/manifest.csv s3://"$destination"
  fi

}

# function to create job
## creates job and returns command to check job status after completed
gen3_replicate_create_job() {
  local source=$1
  local destination=$2
  if [[ ! -z $3 ]]; then
    local profile=$3
    local etag=$(gen3_aws_run aws s3api list-objects --bucket $2 --output json --query '{Name: Contents[].{Key: ETag}}' --prefix manifest.csv --profile $profile|jq -r .Name[].Key)
    local operation="{ \"S3PutObjectCopy\": {\"TargetResource\": \"arn:aws:s3:::$destination\"}}"
    local manifest="{\"Spec\": {\"Format\": \"EXAMPLE_S3BatchOperations_CSV_20180820\",\"Fields\": [\"Bucket\",\"Key\"]},\"Location\": {\"ObjectArn\": \"arn:aws:s3:::$destination/manifest.csv\",\"ETag\": $etag}}"
    local report="{\"Bucket\": \"arn:aws:s3:::$destination\",\"Format\": \"Example_Report_CSV_20180820\",\"Enabled\": true,\"Prefix\": \"reports/copy-with-replace-metadata\",\"ReportScope\": \"AllTasks\"}"
    local roleArn=$(gen3_aws_run aws iam get-role --role-name batch-operations-role --profile $profile |jq -r .Role.Arn)
    local accountId=$(gen3_aws_run aws iam get-role --role-name batch-operations-role --profile $profile |jq -r .Role.Arn |cut -d : -f 5)
    status=$(gen3_aws_run aws s3control create-job --profile $profile --account-id $accountId --manifest "${MANIFEST//$'\n'}" --operation "${OPERATION//$'\n'/}" --report "${REPORT//$'\n'}" --priority 10 --role-arn $roleArn  --region us-east-1 --description "Copy with Replace Metadata" --no-confirmation-required | jq -r .JobId)
    gen3_log_info "Job created. can check status by running gen3 replicate status $status"
  else
    local etag=$(gen3_aws_run aws s3api list-objects --bucket $2 --output json --query '{Name: Contents[].{Key: ETag}}' --prefix manifest.csv |jq -r .Name[].Key | sed -e 's/"//g')
    local OPERATION='{"S3PutObjectCopy": {"TargetResource": "arn:aws:s3:::'$destination'"}}'
    local MANIFEST='{"Spec": {"Format": "S3BatchOperations_CSV_20180820","Fields": ["Bucket","Key"]},"Location": {"ObjectArn": "arn:aws:s3:::'$destination'/manifest.csv","ETag": "'$etag'"}}'
    local REPORT='{"Bucket": "arn:aws:s3:::'$destination'","Format": "Report_CSV_20180820","Enabled": true,"Prefix": "reports/copy-with-replace-metadata","ReportScope": "AllTasks"}'
    local roleArn=$(gen3_aws_run aws iam get-role --role-name batch-operations-role |jq -r .Role.Arn)
    local TAGS="[{\"Key\": \"job\",\"Value\": \"copy\"}]"
    local accountId=$(gen3_aws_run aws iam get-role --role-name batch-operations-role |jq -r .Role.Arn |cut -d : -f 5)
    status=$(aws s3control create-job --debug --account-id "$accountId" --manifest "${MANIFEST//$'\n'}" --operation "${OPERATION//$'\n'/}" --report "${REPORT//$'\n'}" --priority 10 --role-arn $roleArn --client-request-token "$(uuidgen)" --region us-east-1 --description "Copy with Replace Metadata" )
    gen3_log_info "Job created. can check status by running gen3 replicate status $status"
  fi
}

# function to check job status
gen3_replicate_status() {
  local $jobId=$1
  local accountId=$(gen3_aws_run aws iam get-role --role-name batch-operations-role |jq -r .Role.Arn |cut -d : -f 5)
  local status=$(gen3_aws_run aws s3control describe-job --account-id $accountId --job-id $jobId |jq -r .Job.Status)
}



####### IAM part

# function to check if role/policy exists
## if no role call create role
## if no policy create policy, if policy modify policy to support new endpoints

gen3_replicate_init() {
  local source=$1
  local destination=$2
  if [[ ! -z $3 ]]; then
    if [[ ! -z $4 ]]; then
      local destinationAccountId=$3
      local profile=$4
      local destinationRolePolicy="{\"Version\": \"2012-10-17\",\"Statement\": [{\"Sid\": \"AllowBatchOperationsDestinationObjectCOPY\",\"Effect\": \"Allow\",\"Action\": [\"s3:PutObject\",\"s3:PutObjectVersionAcl\",\"s3:PutObjectAcl\",\"s3:PutObjectVersionTagging\",\"s3:PutObjectTagging\",\"s3:GetObject\",\"s3:GetObjectVersion\",\"s3:GetObjectAcl\",\"s3:GetObjectTagging\",\"s3:GetObjectVersionAcl\",\"s3:GetObjectVersionTagging\"],\"Resource\": [\"arn:aws:s3:::$source/*\",\"arn:aws:s3:::$destinaion/*\"]}]}"
# need to only make a joint policy if there was a policy previously.
      local oldPolicy=$(aws s3api get-bucket-policy --bucket $source |jq -r .Policy | jq -r .Statement[])
      local newPolicy="{\"Version\": \"2012-10-17\",\"Statement\": [{\"Sid\": \"AllowBatchOperationsSourceManfiestRead\",\"Effect\": \"Allow\",\"Principal\": {\"AWS\": [\"arn:aws:iam::$destinationAccountId:role/batch-operations-role\"]},\"Action\": [\"s3:GetObject\",\"s3:GetObjectVersion\"],\"Resource\": \"arn:aws:s3:::$source/*\"}]}"
      local bucketPolicy=$(jq -n --arg $oldPolicy --arg $newPolicy '{"Version": "2012-10-17", "Statement": [$oldPolicy,$newPolicy]}')
      gen3_aws_run aws s3api put-bucket-policy --bucket $source --policy "$bucketPolicy"
    else
      gen3_log_error "Gave destination account but didn't specify the aws profile with permissions to that account"
      exit 1
    fi
    if [[ -z $(gen3_aws_run aws iam list-roles --profile $profile | jq -r .Roles[].RoleName |grep batch-operations-role) ]]; then
      gen3_log_info "batch-operations-role not created. Creating role"
      local trustRelationship="{\"Version\": \"2012-10-17\",\"Statement\": [{\"Effect\": \"Allow\",\"Principal\": {\"Service\": \"batchoperations.s3.amazonaws.com\"},\"Action\": \"sts:AssumeRole\"}]}"
      gen3_aws_run aws iam create-role --role-name batch-operations-role --assume-role-policy-document "$trustRelationship" --profile $profile
    fi
    if [[ -z $(gen3_aws_run aws iam list-role-policies --role-name batch-operations-role --profile "$profile" | jq -r .PolicyNames[]) ]]; then
      gen3_log_info "Old policy exists. Modifying for new policy"
      gen3_aws_run aws iam delete-role-policy --role-name batch-opetations-role --policy-name batch-operations-policy --profile $profile
    fi
    local policy="{\"Version\": \"2012-10-17\",    \"Statement\": [        {            \"Action\": [                \"s3:PutObject\",                \"s3:PutObjectAcl\",                \"s3:PutObjectTagging\"            ],            \"Effect\": \"Allow\",            \"Resource\": \"arn:aws:s3:::$destination/*\"        },        {            \"Action\": [                \"s3:GetObject\",                \"s3:GetObjectAcl\",                \"s3:GetObjectTagging\"            ],            \"Effect\": \"Allow\",            \"Resource\": \"arn:aws:s3:::$source/*\"        },        {            \"Effect\": \"Allow\",            \"Action\": [                \"s3:GetObject\",                \"s3:GetObjectVersion\",                \"s3:GetBucketLocation\"            ],            \"Resource\": [                \"arn:aws:s3:::$destination/*\"            ]        },        {            \"Effect\": \"Allow\",            \"Action\": [                \"s3:PutObject\",                \"s3:GetBucketLocation\"            ],            \"Resource\": [                \"arn:aws:s3:::$destination/*\"            ]        }    ]}"
    gen3_aws_run aws iam put-role-policy --role-name batch-operations-role --policy-name batch-operations-policy --policy-document $policy --profile $profile
  else
    if [[ -z $(gen3_aws_run aws iam list-roles | jq -r .Roles[].RoleName |grep batch-operations-role) ]]; then
      gen3_log_info "batch-operations-role not created. Creating role"
      local trustRelationship="{\"Version\": \"2012-10-17\",\"Statement\": [{\"Effect\": \"Allow\",\"Principal\": {\"Service\": \"batchoperations.s3.amazonaws.com\"},\"Action\": \"sts:AssumeRole\"}]}"
      gen3_aws_run aws iam create-role --role-name batch-operations-role --assume-role-policy-document "$trustRelationship"
    fi

    if [[ -z $(gen3_aws_run aws iam list-role-policies --role-name batch-operations-role | jq -r .PolicyNames[]) ]]; then
      gen3_log_info "Old policy exists. Modifying for new policy"
      gen3_aws_run aws iam delete-role-policy --role-name batch-opetations-role --policy-name batch-operations-policy
    fi
    local policy="{\"Version\": \"2012-10-17\",    \"Statement\": [        {            \"Action\": [                \"s3:PutObject\",                \"s3:PutObjectAcl\",                \"s3:PutObjectTagging\"            ],            \"Effect\": \"Allow\",            \"Resource\": \"arn:aws:s3:::$destination/*\"        },        {            \"Action\": [                \"s3:GetObject\",                \"s3:GetObjectAcl\",                \"s3:GetObjectTagging\"            ],            \"Effect\": \"Allow\",            \"Resource\": \"arn:aws:s3:::$source/*\"        },        {            \"Effect\": \"Allow\",            \"Action\": [                \"s3:GetObject\",                \"s3:GetObjectVersion\",                \"s3:GetBucketLocation\"            ],            \"Resource\": [                \"arn:aws:s3:::$destination/*\"            ]        },        {            \"Effect\": \"Allow\",            \"Action\": [                \"s3:PutObject\",                \"s3:GetBucketLocation\"            ],            \"Resource\": [                \"arn:aws:s3:::$destination/*\"            ]        }    ]}"
    gen3_aws_run aws iam put-role-policy --role-name batch-operations-role --policy-name batch-operations-policy --policy-document "$policy"
  fi
}

gen3_replication() {
  gen3_replicate_init $@
  gen3_replicate_create_manifest $@
  gen3_replicate_create_job $@
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
    gen3_replicate_creds "$@"
    ;;
  'help')
    gen3_replicate_creds "$@"
    ;;
  *)
    gen3_replicate_help
    ;;
esac
exit $?