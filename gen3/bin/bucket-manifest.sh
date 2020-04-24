#!/bin/bash


source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


# lib -----------------------------------

# Creates
gen3_create_manifest() {
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

initialization() {

  source_bucket=$1
  manifest_bucket=$2  

  ####### Create lambda-generate-metadata role ################
  if [[ -z $(gen3_aws_run aws iam list-roles | jq -r .Roles[].RoleName | grep lambda-generate-metadata) ]]; then
    gen3_log_info " Creating lambda-generate-metadata role ...."
    aws iam create-role --role-name lambda-generate-metadata --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
          "Service": "lambda.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
        ]
    }'
    if [ ! $? == 0 ]; then
        gen3_log_info " Can not create lambda-generate-metadata role"
        exit 1
    fi
  else
    gen3_log_info "lambda-generate-metadata role already exist"
  fi

  cat << EOF > $WORKSPACE/policy.json
{
   "Version":"2012-10-17",
  "Statement":[
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "arn:aws:s3:::${source_bucket}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::${manifest_bucket}/*"
      ]
    }
  ]
}
EOF
  aws iam put-role-policy \
  --role-name lambda-generate-metadata \
  --policy-name LambdaMetadataJobPolicy \
  --policy-document file://policy.json

  rm $WORKSPACE/policy.json

  if [[ -z $(gen3_aws_run aws lambda list-functions | jq -r .Functions[].FunctionName | grep object-hash-compute) ]] then;
    gen3_log_info " Creating lambda function ...."
    gen3 awslambda create 
  fi

  
}
gen3_generate_manifest() {
  initialization $@
}

if [[ $# -lt 2 ]]; then
    gen3_log_info "lambda-generate-metadata role already exist"
fi

command="$1"
shift
case "$command" in
  'bucket')
    gen3_generate_manifest "$@"
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