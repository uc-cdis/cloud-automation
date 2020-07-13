#!/bin/bash
#
## Used to replicate an AWS bucket using S3 batch operations


source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


# set the profiles to default in case they are not set. Implies same account replication from default (adminvm) profile
sourceProfile="default"
profileWithRole="default"
profileWithSourceBucket="default"
profileWithDestinationBucket="default"

# Creates a manifest and puts it in destination bucket. Puts in destination to avoid inadvertantly copying over another object, being the manifest.
gen3_replicate_create_manifest() {
  if [[ -f $WORKSPACE/tempKeyFile ]]; then
    gen3_log_info "previous key file found. Deleting"
    rm $WORKSPACE/tempKeyFile
  fi
  gen3_log_info "Creating manifest of objects in the source account. Could take a while depending on the size of the bucket."
  aws s3api list-objects --bucket "$sourceBucket" --query 'Contents[].{Key: Key}' --profile $profileWithSourceBucket | jq -r '.[].Key' >> "$WORKSPACE/tempKeyFile"
  if [[ -f $WORKSPACE/manifest.csv ]]; then
    rm $WORKSPACE/manifest.csv
  fi
  while read line; do
    echo "$sourceBucket,$line" >> $WORKSPACE/manifest.csv
  done<$WORKSPACE/tempKeyFile
  rm $WORKSPACE/tempKeyFile
  aws s3 cp $WORKSPACE/manifest.csv s3://"$destinationBucket" --profile $profileWithDestinationBucket
  rm $WORKSPACE/manifest.csv
}

# function to create job
## creates job and returns command to check job status after completed
gen3_replicate_create_job() {
  local etag=$(aws s3api list-objects --profile $profileWithDestinationBucket --bucket $destinationBucket --output json --query '{Name: Contents[].{Key: ETag}}' --prefix manifest.csv | jq -r .Name[].Key | sed -e 's/"//g')
  local OPERATION='{"S3PutObjectCopy": {"TargetResource": "arn:aws:s3:::'$destinationBucket'", "MetadataDirective": "REPLACE", "CannedAccessControlList": "bucket-owner-full-control"}}'
  local MANIFEST='{"Spec": {"Format": "S3BatchOperations_CSV_20180820","Fields": ["Bucket","Key"]},"Location": {"ObjectArn": "arn:aws:s3:::'$destinationBucket'/manifest.csv","ETag": "'$etag'"}}'
  local REPORT='{"Bucket": "arn:aws:s3:::'$destinationBucket'","Format": "Report_CSV_20180820","Enabled": true,"Prefix": "reports/copy-with-replace-metadata","ReportScope": "AllTasks"}'
  local roleArn=$(aws iam get-role --profile $profileWithRole --role-name batch-operations-role | jq -r .Role.Arn)
  status=$(aws s3control create-job --profile $profileWithRole --account-id $roleAccountId --manifest "${MANIFEST//$'\n'}" --operation "${OPERATION//$'\n'/}" --report "${REPORT//$'\n'}" --priority 10 --role-arn $roleArn  --region us-east-1 --description "Copy with Replace Metadata" --no-confirmation-required | jq -r .JobId)
  echo $status
}

# function to check job status
gen3_replicate_status() {
  local jobId=$1
  local status=$(aws s3control describe-job --account-id $roleAccountId --job-id $jobId --profile $profileWithRole --region us-east-1 | jq -r .Job.Status)
  while [[ $status != 'Complete' ]]; do
    gen3_log_info "Waiting for job to complete. Current status $status"
    local status=$(aws s3control describe-job --account-id $roleAccountId --job-id $jobId --profile $profileWithRole --region us-east-1 | jq -r .Job.Status)
    sleep 10
    if [[ $status == "Failed" ]]; then
      gen3_log_err "Job has failed. Check the logs in the s3 console."
      gen3_replicate_cleanup
      exit 1
    fi
  done
  echo $status
}

# Need to check profiles work and have permissions to buckets
gen3_replicate_verify_bucket_access() {
  # check if profile with role has permissions to create roles
  gen3_log_info "Checking source profile $profileWithSourceBucket has permissions to source bucket $sourceBucket"
  if [[ -z $(aws s3 ls $sourceBucket --profile $profileWithSourceBucket) ]]; then
    gen3_log_err "Source bucket $sourceBucket does not exist or source profile $profileWithSourceBucket does not have permissions to it"
    exit 1
  fi
  gen3_log_info "Checking destination profile $profileWithDestinationBucket has permissions to destination bucket $destinationBucket"
}


# initialize the profiles, roles and policies
gen3_replicate_init() {
  # The runFromSource should take priority in the if statement becuase it implies there is a destination account and not all run in the same account
  if [[ ! -z $runFromSource ]]; then
    profileWithRole=$sourceProfile
    profileWithSourceBucket=$sourceProfile
    profileWithDestinationBucket=$destinationProfile
    roleAccountId=$(aws sts get-caller-identity --profile $sourceProfile |jq -r .Account)
  # if destination is set but you are not running from source account then you will be running from destination account with the source bucke in either adminvm account if sourceprofile not set or in specified source profile
  elif [[ ! -z $destinationProfile ]]; then
    profileWithRole=$destinationProfile
    profileWithSourceBucket=$sourceProfile
    profileWithDestinationBucket=$destinationProfile
    roleAccountId=$(aws sts get-caller-identity --profile $destinationProfile |jq -r .Account)
  # If these are not set then assume everything is run from sourceProfile, sourceProfile defaults to default profile (adminvm profile) if not set
  else
    profileWithRole=$sourceProfile
    profileWithSourceBucket=$sourceProfile
    profileWithDestinationBucket=$sourceProfile
    roleAccountId=$(aws sts get-caller-identity --profile $sourceProfile |jq -r .Account)
  fi
  # Verify profile can reach buckets
  gen3_replicate_verify_bucket_access
  # Check if batch operations role exists. Create if it doesn't.
  if [[ -z $(aws iam list-roles --profile $profileWithRole | jq -r .Roles[].RoleName | grep batch-operations-role) ]]; then
    gen3_log_info "Creating batch operations role using profile $profileWithRole"
    local trustRelationship="{\"Version\": \"2012-10-17\",\"Statement\": [{\"Effect\": \"Allow\",\"Principal\": {\"Service\": \"batchoperations.s3.amazonaws.com\"},\"Action\": \"sts:AssumeRole\"}]}"
    aws iam create-role --role-name batch-operations-role --assume-role-policy-document "$trustRelationship"  --profile $profileWithRole
  fi
  sleep 30
  local destinationRolePolicy="{\"Version\": \"2012-10-17\",\"Statement\": [{\"Sid\": \"AllowBatchOperationsDestinationObjectCOPY\",\"Effect\": \"Allow\",\"Action\": [\"s3:PutObject\",\"s3:PutObjectVersionAcl\",\"s3:PutObjectAcl\",\"s3:PutObjectVersionTagging\",\"s3:PutObjectTagging\",\"s3:GetObject\",\"s3:GetObjectVersion\",\"s3:GetObjectAcl\",\"s3:GetObjectTagging\",\"s3:GetObjectVersionAcl\",\"s3:GetObjectVersionTagging\"],\"Resource\": [\"arn:aws:s3:::$sourceBucket/*\",\"arn:aws:s3:::$destinationBucket/*\"]}]}"
  # need to only make a joint policy if there was a policy previously.
  gen3_log_info "Checking for old policies and modfying bucket policy to add batch operations policy"
  # Save the old bucket policy to reset after so that fence-bot and potentially other service accounts don't lose access to the buckets
  resetSourceBucketPolicy=$(aws s3api get-bucket-policy --bucket $sourceBucket --profile $profileWithSourceBucket | jq -r .Policy )
  local oldSourceBucketPolicy=$(aws s3api get-bucket-policy --bucket $sourceBucket --profile $profileWithSourceBucket | jq -r .Policy | jq -r .Statement[] )
  local newSourceBucketPolicy=$(echo "{\"Sid\": \"AllowBatchOperationsSourceManfiestRead\",\"Effect\": \"Allow\",\"Principal\": {\"AWS\": [\"arn:aws:iam::$roleAccountId:role/batch-operations-role\"]},\"Action\": [\"s3:GetObject\",\"s3:GetObjectVersion\"],\"Resource\": \"arn:aws:s3:::$sourceBucket/*\"}" |jq -r .)
  if [[ -z $oldSourceBucketPolicy ]]; then
    local sourceBucketPolicy='{"Version": "2012-10-17", "Statement": ['$newSourceBucketPolicy']}'
  else
    gen3_log_info "Found old bucket policy on source bucket $oldSourceBucketPolicy Modifying it to add batch operations bucket policy"
    local sourceBucketPolicy='{"Version": "2012-10-17", "Statement": ['$oldSourceBucketPolicy','$newSourceBucketPolicy']}'
  fi
  # sleep to allow role to fully generate for policy
  sleep 5
  aws s3api put-bucket-policy --bucket $sourceBucket --policy "$sourceBucketPolicy" --profile $profileWithSourceBucket 
  # If running from source account on cross account replicate, make sure to add bucket policy to allow to put the report and read the manifest
  if [[ ! -z $runFromSource ]]; then
    resetDestinationBucketPolicy=$(aws s3api get-bucket-policy --bucket $destinationBucket --profile $profileWithDestinationBucket | jq -r .Policy )
    local oldDestinationBucketPolicy=$(aws s3api get-bucket-policy --bucket $destinationBucket --profile $profileWithDestinationBucket | jq -r .Policy | jq -r .Statement[] )
    local newDestinationBucketPolicy=$(echo "{\"Sid\": \"AllowBatchOperationsSourceManfiestRead\",\"Effect\": \"Allow\",\"Principal\": {\"AWS\": [\"arn:aws:iam::$roleAccountId:role/batch-operations-role\"]},\"Action\": [\"s3:Get*\",\"s3:Put*\"],\"Resource\": \"arn:aws:s3:::$destinationBucket/*\"}" |jq -r .)
    if [[ -z $oldDestinationBucketPolicy ]]; then
      local destinationBucketPolicy='{"Version": "2012-10-17", "Statement": ['$newDestinationBucketPolicy']}'
    else
      gen3_log_info "Found old bucket policy on destination bucket $oldDestinationBucketPolicy Modifying it to add batch operations bucket policy"
      local destinationBucketPolicy='{"Version": "2012-10-17", "Statement": ['$oldDestinationBucketPolicy','$newDestinationBucketPolicy']}'
    fi
    aws s3api put-bucket-policy --bucket $destinationBucket --policy "$destinationBucketPolicy" --profile $profileWithDestinationBucket 
  fi
  if [[ ! -z $(aws iam list-role-policies --role-name batch-operations-role --profile "$profileWithRole" | jq -r .PolicyNames[]) ]]; then
    gen3_log_info "Old policy exists. Removing in favor of new policy"
    aws iam delete-role-policy --role-name batch-operations-role --policy-name batch-operations-policy --profile "$profileWithRole"
  fi
  local policy="{\"Version\": \"2012-10-17\", \"Statement\": [ { \"Action\": [ \"s3:PutObject\", \"s3:PutObjectAcl\", \"s3:PutObjectTagging\" ], \"Effect\": \"Allow\", \"Resource\": \"arn:aws:s3:::$destinationBucket/*\" }, { \"Action\": [ \"s3:GetObject\", \"s3:GetObjectAcl\", \"s3:GetObjectTagging\" ], \"Effect\": \"Allow\", \"Resource\": \"arn:aws:s3:::$sourceBucket/*\" }, { \"Effect\": \"Allow\", \"Action\": [ \"s3:GetObject\", \"s3:GetObjectVersion\", \"s3:GetBucketLocation\" ], \"Resource\": [ \"arn:aws:s3:::$destinationBucket/*\" ] }, { \"Effect\": \"Allow\", \"Action\": [ \"s3:PutObject\", \"s3:GetBucketLocation\" ], \"Resource\": [ \"arn:aws:s3:::$destinationBucket/*\" ] }    ]}"
  aws iam put-role-policy --role-name batch-operations-role --policy-name batch-operations-policy --policy-document "${policy//$'\n'}" --profile $profileWithRole
  # If the role policy is not created after that it implies the profile does not have permission to create the policy and the process should be stopped.
  sleep 30
  local counter=0
  while [[ -z $(aws iam list-role-policies --role-name batch-operations-role --profile $profileWithRole | jq -r .PolicyNames[]) ]] && [[ "$(aws s3api get-bucket-policy --bucket $sourceBucket | jq -rc .Policy)" != *"AllowBatchOperationsSourceManfiestRead"* ]]; do
    gen3_log_info "Waiting for role and policies to be verified"
    let counter=counter+1
    if [[ $counter > 6 ]]; then
      gen3_log_err "Could not successfully create role policy. Please ensure profile $profileWithRole has permissions to create policies"
      gen3_replicate_cleanup
      exit 1
    fi
    sleep 10
  done
  sleep 30
  # Wait a little extra to ensure policies are actually in effect after they're applied
  gen3_log_info "Waiting for policies to take effect"
}

gen3_replication() {
  gen3_replicate_init
  gen3_replicate_create_manifest
  status=$(gen3_replicate_create_job)
  gen3_replicate_status $status
  gen3_replicate_cleanup
}

gen3_replicate_cleanup() {
  gen3_log_info "Cleaning up roles/policies"
  # if you are running from the source account, implies there is a destination account too
  # need to also just check source profile is there without run from source
  gen3_log_info "Deleting role policy"
  aws iam delete-role-policy --role-name batch-operations-role --policy-name batch-operations-policy --profile $profileWithRole
  gen3_log_info "Deleting role"
  aws iam delete-role --role-name batch-operations-role --profile $profileWithRole
  # always on source profile, use what was initialized for profile
  if [[ ! -z $resetSourceBucketPolicy ]]; then
    gen3_log_info "Old source bucket policy found. Reverting back to it."
    aws s3api put-bucket-policy --bucket $sourceBucket --policy "$resetSourceBucketPolicy" --profile $profileWithSourceBucket
  else
    gen3_log_info "Deleting source bucket policy"
    aws s3api delete-bucket-policy --bucket $sourceBucket --profile $profileWithSourceBucket
  fi
  # always on source profile, use what was initialized for profile
  if [[ ! -z $resetDestinationBucketPolicy ]]; then
    gen3_log_info "Old destination bucket policy found. Reverting back to it."
    aws s3api put-bucket-policy --bucket $destinationBucket --policy "$resetDestinationBucketPolicy" --profile $profileWithSourceBucket
  else
    gen3_log_info "Deleting destination bucket policy"
    aws s3api delete-bucket-policy --bucket $destinationBucket --profile $profileWithDestinationBucket
  fi 
}


gen3_replicate_help() {
  gen3 help replicate
}

OPTIND=1 
OPTSPEC="h:-:"
while getopts "$OPTSPEC" optchar; do
  case "${optchar}" in
    -)
      case "${OPTARG}" in
        source-bucket)
          sourceBucket="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          ;;
        source-bucket=*)
          sourceBucket=${OPTARG#*=}
          ;;
        destination-bucket)
          destinationBucket="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          ;;
        destination-bucket=*)
          destinationBucket=${OPTARG#*=}
          ;;
        destination-profile)
          destinationProfile="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          ;;
        destination-profile=*)
          destinationProfile=${OPTARG#*=}
          ;;
        source-profile)
          sourceProfile="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          ;;
        source-profile=*)
          sourceProfile=${OPTARG#*=}
          ;;
        use-source-account)
          runFromSource=1
          ;;
        all=*)
          INSTANCE="ALL"
          INTERVAL=${OPTARG#*=}
          ;;
        help)
          gen3_replicate_help
          exit
          ;;
        *)
          if [ "$OPTERR" = 1 ] && [ "${OPTSPEC:0:1}" != ":" ]; then
            echo "Unknown option --${OPTARG}" >&2
            gen3_replicate_help
            exit 2
          fi
          ;;
      esac;;
    h)
      gen3_replicate_help
      exit
      ;;
    *)
      if [ "$OPTERR" != 1 ] || [ "${OPTSPEC:0:1}" = ":" ]; then
        echo "Non-option argument: '-${OPTARG}'" >&2
        gen3_replicate_help
        exit 2
      fi
      ;;
    esac
done

# Stop if required params are not set
if [[ -z $sourceBucket ]] || [[ -z $destinationBucket ]]; then
  gen3_log_error "Missing source and destination bucket"
  gen3_replicate_help
else
  gen3_replication
fi
