#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

hostname=$(gen3 api hostname)
export hostname
namespace=$(gen3 api namespace)
export namespace

# Deploy the dicom-server service
setup_database_and_config() {
  gen3_log_info "setting up dicom-server DB and config"

  if g3kubectl describe secret orthanc-s3-g3auto > /dev/null 2>&1; then
    gen3_log_info "orthanc-s3-g3auto secret already configured"
    return 0
  fi
  if [[ -n "$JENKINS_HOME" || ! -f "$(gen3_secrets_folder)/creds.json" ]]; then
    gen3_log_err "skipping db setup in non-adminvm environment"
    return 0
  fi

  # Setup config files that dicom-server consumes
  local secretsFolder
  secretsFolder="$(gen3_secrets_folder)/g3auto/orthanc-s3"
  if [[ ! -f "$secretsFolder/orthanc_config_overwrites.json" ]]; then
    if [[ ! -f "$secretsFolder/dbcreds.json" ]]; then
      if ! gen3 db setup orthanc-s3; then
        gen3_log_err "Failed setting up orthanc database for dicom-server"
        return 1
      fi
    fi

    ref_hostname="${hostname//\./-}"
    bucketname="${ref_hostname}-orthanc-storage"
    awsuser="${ref_hostname}-orthanc"

    if [[ ! -f "$secretsFolder/s3creds.json" ]]; then
      gen3 s3 create "${bucketname}"
      gen3 awsuser create "${awsuser}"
      gen3 s3 attach-bucket-policy "${bucketname}" --read-write --user-name "${awsuser}"

      user=$(gen3 secrets decode "${awsuser}"-g3auto awsusercreds.json)
      key_id=$(jq -r .id <<< "$user")
      access_key=$(jq -r .secret <<< "$user")

      cat - > "$secretsFolder/s3creds.json" <<EOM
{ 
  "bucket": "${bucketname}",
  "region": "us-east-1",
  "aws_access_key_id": "${key_id}",
  "aws_secret_access_key": "${access_key}"
}
EOM
    fi

    cat - > "$secretsFolder/orthanc_config_overwrites.json" <<EOM
{
  "RemoteAccessAllowed" : true,
  "AuthenticationEnabled": true,
  "RegisteredUsers" : {
    "public" : "hello"
  },
  "AwsS3Storage" : {
    "BucketName": "$(jq -r .bucket < $secretsFolder/s3creds.json)",
    "Region" : "$(jq -r .region < $secretsFolder/s3creds.json)",
    "AccessKey" : "$(jq -r .aws_access_key_id < $secretsFolder/s3creds.json)",
    "SecretKey" : "$(jq -r .aws_secret_access_key < $secretsFolder/s3creds.json)"
  },
  "PostgreSQL": {
    "EnableIndex": true,
    "EnableStorage": false,
    "Port": 5432,
    "Host": "$(jq -r .db_host < $secretsFolder/dbcreds.json)",
    "Database": "$(jq -r .db_database < $secretsFolder/dbcreds.json)",
    "Username": "$(jq -r .db_username < $secretsFolder/dbcreds.json)",
    "Password": "$(jq -r .db_password < $secretsFolder/dbcreds.json)",
    "IndexConnectionsCount": 5,
    "Lock": false
  }
}
EOM
  fi

  if g3k_manifest_lookup '.versions["dicom-server"]' > /dev/null 2>&1; then
    export DICOM_SERVER_URL="/dicom-server"
    gen3_log_info "attaching ohif viewer to old dicom-server (orthanc w/ aurora)"
  fi

  if g3k_manifest_lookup .versions.orthanc > /dev/null 2>&1; then
    export DICOM_SERVER_URL="/orthanc"
    gen3_log_info "attaching ohif viewer to new dicom-server (orthanc w/ s3)"
  fi

  envsubst <"${GEN3_HOME}/kube/services/ohif-viewer/app-config.js" > "$secretsFolder/app-config.js"

  gen3 secrets sync 'setup orthanc-s3-g3auto secrets'
}

if ! setup_database_and_config; then
  gen3_log_err "kube-setup-dicom bailing out - database/config failed setup"
  exit 1
fi

gen3 roll orthanc
g3kubectl apply -f "${GEN3_HOME}/kube/services/orthanc/orthanc-service.yaml"

cat <<EOM
The orthanc service has been deployed onto the k8s cluster.
EOM

# Deploy the dicom-viewer service
gen3 roll ohif-viewer
g3kubectl apply -f "${GEN3_HOME}/kube/services/ohif-viewer/ohif-viewer-service.yaml"

cat <<EOM
The ohif-viewer service has been deployed onto the k8s cluster.
EOM
