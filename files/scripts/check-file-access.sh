source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


head_object_task() {
  file=$(echo $1 | rev | cut -d '/' -f 1 | rev)
  aws s3api head-object --bucket "$2" --key "$1" --profile "$3" > /dev/null 2>&1
  if [[ $? != 0 ]]; then
    gen3_log_err "$3 can not access file: $1 in bucket: $2"
    echo "$3 can not access file: $1 in bucket: $2" >> ~/results/$2-failed
  else
    gen3_log_info "$3 can access file: $1 in bucket: $2"
  fi
}


check_object_access() {
  gen3_log_info "Checking file access to files within buckets configured in public fence-config"
  buckets=$(kubectl get cm manifest-fence -o json | jq -r '.data."fence-config-public.yaml"' | yq -r '.S3_BUCKETS | keys | .[]')
  for bucket in $buckets; do
    fenceUser=$(kubectl get cm manifest-fence -o json | jq -r '.data."fence-config-public.yaml"' | yq -r '.S3_BUCKETS' | yq -r '.'\"$bucket\"'.cred')
    if [[ $(kubectl get cm manifest-fence -o json | jq -r '.data."fence-config-public.yaml"' |  yq -r '.S3_BUCKETS.'\"$bucket\"' | has("role-arn")') != "false" ]]; then
       profile=$(kubectl get cm manifest-fence -o json | jq -r '.data."fence-config-public.yaml"' | yq -r '.S3_BUCKETS.'\"$bucket\"'."role-arn"' | rev | cut -d '/' -f -1 | rev )
    elif [[ $(kubectl get cm manifest-fence -o json | jq -r '.data."fence-config-public.yaml"' |  yq -r '.S3_BUCKETS.'\"$bucket\"'.cred') == "*" ]]; then
       profile=""
    else
      profile=$(kubectl get cm manifest-fence -o json | jq -r '.data."fence-config-public.yaml"' |  yq -r '.S3_BUCKETS.'\"$bucket\"'.cred')
    fi
    gen3 psql indexd -c "select url from index_record_url where url like 's3://$bucket/%'" | grep s3 > $bucket-files
    gen3_log_info "Checking objects in bucket:$bucket with profile:$profile"
    while read fileLocation; do
      file=$(echo $fileLocation | cut -d '/' -f4-)
      ((i=i%50)); ((i++==0)) && wait
      head_object_task "$file" "$bucket" "$profile" &
    done<$bucket-files
    rm $bucket-files
  done

  gen3_log_info "Checking file access to files within buckets configured in private fence-config"
  buckets=$(gen3 secrets decode fence-config fence-config.yaml | yq -r '.S3_BUCKETS | keys | .[]')
  for bucket in $buckets; do
    fenceUser=$(gen3 secrets decode fence-config fence-config.yaml | yq -r '.S3_BUCKETS' | yq -r '.'\"$bucket\"'.cred')
    if [[ $(gen3 secrets decode fence-config fence-config.yaml |  yq -r '.S3_BUCKETS.'\"$bucket\"' | has("role-arn")') != "false" ]]; then
       profile=$(gen3 secrets decode fence-config fence-config.yaml | yq -r '.S3_BUCKETS.'\"$bucket\"'."role-arn"' | rev | cut -d '/' -f -1 | rev )
    elif [[ $(gen3 secrets decode fence-config fence-config.yaml |  yq -r '.S3_BUCKETS.'\"$bucket\"'.cred') == "*" ]]; then
       profile=""
    else
      profile=$(gen3 secrets decode fence-config fence-config.yaml |  yq -r '.S3_BUCKETS.'\"$bucket\"'.cred')
    fi
    gen3 psql indexd -c "select url from index_record_url where url like 's3://$bucket/%'" | grep s3 > $bucket-files
    gen3_log_info "Checking objects in bucket:$bucket with profile:$profile"
    while read fileLocation; do
      file=$(echo $fileLocation | cut -d '/' -f4-)
      ((i=i%50)); ((i++==0)) && wait
      head_object_task "$file" "$bucket" "$profile" &
    done<$bucket-files
    rm $bucket-files
  done
}

initialize_creds() {
  gen3_log_info "Initializing AWS profiles"
  # If the .aws creds directory doesn't exist make it
  if [[ ! -d ~/.aws ]]; then
    mkdir ~/.aws
  fi
  # Make sure there is an empty results bucket for the results of the job
  if [[ ! -d ~/results ]]; then
    mkdir results
  else
    rm -rf ~/results
    mkdir ~/results
  fi
  # If the .aws/credentials file doesn't exist, then create it, if it does, move it and initialize a new copy for testing
  if [[ -f ~/.aws/credentials ]]; then
    mv ~/.aws/credentials ~/.aws/credentials-bck
  else
    touch ~/.aws/credentials
  fi
  for key in $(gen3 secrets decode fence-config fence-config.yaml | yq -r '.AWS_CREDENTIALS | keys | .[]'); do
    gen3_log_info "Creating aws profile for $key"
    cat <<- EOF >> ~/.aws/credentials
[$key]
aws_access_key_id=$(gen3 secrets decode fence-config fence-config.yaml | yq -r '.AWS_CREDENTIALS.'\"$key\"'.aws_access_key_id')
aws_secret_access_key=$(gen3 secrets decode fence-config fence-config.yaml | yq -r '.AWS_CREDENTIALS.'\"$key\"'.aws_secret_access_key')
EOF
  done
  cmRoleArns=$(kubectl get cm manifest-fence -o json | jq -r '.data."fence-config-public.yaml"' | yq -r '.S3_BUCKETS[] | select(."role-arn" != null) | ."role-arn"' 2>/dev/null | sort  | uniq)
  secretRoleArns=$(gen3 secrets decode fence-config fence-config.yaml | yq -r '.S3_BUCKETS[] |  select(."role-arn" != null) | ."role-arn"' 2>/dev/null | sort  | uniq)
  for key in $cmRoleArns; do
    gen3_log_info "Creating aws profile for $key"
    cred=$(kubectl get cm manifest-fence -o json | jq -r '.data."fence-config-public.yaml"' | yq -r '.S3_BUCKETS[] | select(."role-arn" != null) | select(."role-arn" == '\"$key\"').cred' | sort | uniq)
    profileName=$(echo $key | rev | cut -d '/' -f 1 | rev)
    cat <<- EOF >> ~/.aws/credentials
[$profileName]
role_arn=$key
source_profile=$cred
EOF
  done
  for key in $secretRoleArns; do
    gen3_log_info "Creating aws profile for $key"
    cred=$(gen3 secrets decode fence-config fence-config.yaml | yq -r '.S3_BUCKETS[] | select(."role-arn" != null) | select(."role-arn" == '\"$key\"').cred' | sort | uniq)
    profileName=$(echo $key | rev | cut -d '/' -f 1 | rev)
    cat <<- EOF >> ~/.aws/credentials
[$profileName]
role_arn=$key
source_profile=$cred
EOF
  done
}

reset_creds() {
  if [[ -f ~/.aws/credentials-bck ]]; then
    mv ~/.aws/credentials-bck ~/.aws/credentials
  else
    rm ~/.aws/credentials
  fi
}

store_results() {
  tar -cvf results.tar.gz results
  gen3 api access-token emalinowski@uchicago.edu | grep ey > accessToken
  ACCESS_TOKEN=$(cat accessToken)
  url=$(curl -s -v -X POST "fence-service/data/upload" --header "Authorization: Bearer ${ACCESS_TOKEN}" -d '{"file_name": "results.tar.gz","expires_in": 1200}'  -H 'Content-Type: application/json' | jq -r .url )
  curl -iLkv -X PUT $url -d @results.tar.gz
}

initialize_creds
check_object_access
store_results
reset_creds
