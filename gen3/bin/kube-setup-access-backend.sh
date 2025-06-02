#!/bin/bash
#
# Setup bucket and creds for access backend
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

#
# access-backend requires dynamodb
#
setup_access_backend() {
  local secret
  local secretsFolder="$(gen3_secrets_folder)/g3auto/access-backend"
  if ! secret="$(g3kubectl get secret access-backend-g3auto -o json 2> /dev/null)" || "false" == "$(jq -r '.data | has("creds.json")' <<< "$secret")"; then # pragma: allowlist secret
    # access-backend-g3auto secret does not exist # pragma: allowlist secret
    # maybe we just need to sync secrets from the file system
    if [[ -f "${secretsFolder}/creds.json" ]]; then
        gen3 secrets sync "setup access-backend secrets"
    else
      mkdir -p "$secretsFolder"
    fi
  fi
  local hostname
  if ! hostname="$(gen3 api hostname)"; then
    gen3_log_err "could not determine hostname from manifest-global - bailing out of access-backend setup"
    return 1
  fi

  gen3_log_info "setting up access-backend service ..."

  if [[ -n "$JENKINS_HOME" || ! -f "$(gen3_secrets_folder)/creds.json" ]]; then
    gen3_log_err "skipping db setup in non-adminvm environment"
    return 0
  fi
  # Setup .env file that access-backend-service consumes
  if [[ ! -f "$secretsFolder/access-backend.env" ]]; then
    local secretsFolder="$(gen3_secrets_folder)/g3auto/access-backend"
    # if [[ ! -f "$secretsFolder/dbcreds.json" ]]; then
    #   if ! gen3 db setup access-backend; then
    #     gen3_log_err "Failed setting up database for access-backend service"
    #     return 1
    #   fi
    # fi
    touch "$secretsFolder/dbcreds.json"
    if [[ ! -f "$secretsFolder/dbcreds.json" ]]; then
      gen3_log_err "dbcreds not present in Gen3Secrets/"
      return 1
    fi

#     cat - > "cors.json" <<EOM
# {
#   "CORSRules": [
#     {
#       "AllowedOrigins": ["$allowedOrigin"],
#       "AllowedHeaders": ["*"],
#       "AllowedMethods": ["PUT", "POST", "DELETE"],
#       "MaxAgeSeconds": 3000,
#       "ExposeHeaders": ["x-amz-server-side-encryption"]
#     },
#     {
#       "AllowedOrigins": ["*"],
#       "AllowedHeaders": ["Authorization"],
#       "AllowedMethods": ["GET"],
#       "MaxAgeSeconds": 3000
#     }
#   ]
# }
# EOM

#     echo "enabling CORS on the bucket"
#     aws s3api put-bucket-cors --bucket "$bucketName" --cors-configuration file://cors.json

    local saName=$(echo "access-${hostname//./-}" | head -c63)
    if ! g3kubectl get sa "$saName" > /dev/null 2>&1; then
      local roleName
      if ! g3kubectl get sa access-backend-sa > /dev/null 2>&1; then
        roleName="$(gen3 api safe-name access-backend)"
        gen3 awsrole create "$roleName" access-backend-sa
        cat - > "access-backend-aws-policy.json" <<EOM
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "GlobalDynamodbAdmin",
            "Effect": "Allow",
            "Action": "dynamodb:*",
            "Resource": [
                "arn:aws:dynamodb:::table/*",
                "arn:aws:dynamodb:*:*:table/*"
            ]
        },
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": "kms:*",
            "Resource": "*"
        }
    ]
}
EOM
        policy=$(cat access-backend-aws-policy.json)
        aws iam create-policy --policy-name $roleName --policy-document "$policy"
        accountNumber=$(aws sts get-caller-identity | jq -r .Account)
        sleep 15
        gen3 awsrole attach-policy arn:aws:iam::$accountNumber:policy/$roleName --role-name $roleName
      fi
      gen3_log_info "created service account '${saName}' with dynamodb access"
      gen3_log_info "created role name '${roleName}'"
      # TODO do I need the following: ???
      # gen3 s3 attach-bucket-policy "$bucketName" --read-write --role-name "${role_name}"
      # gen3_log_info "attached read-write bucket policy to '${bucketName}' for role '${role_name}'"
    fi

    cat - > "$secretsFolder/access-backend.env" <<EOM
DEBUG=False
extra_args=$(jq -r .extra_args < "$secretsFolder/dbcreds.json")
ADMIN_USERS=
GH_ORG=
GH_REPO=
GH_FILE=
GH_KEY=
JWT_ISSUERS=
REVIEW_REQUESTS_ACCESS=
JWT_SIGNING_KEYS=
BASE_USERYAML_PATH=user.yaml
EOM
    gen3 secrets sync 'setup access-backend credentials'
  fi

  # Setup default user.yaml file that access-backend-service consumes
  if [[ ! -f "$secretsFolder/user.yaml" ]]; then
    cat - > "$secretsFolder/user.yaml" <<EOM
clients:
  gen3testclient:
    policies:
    - all_programs_reader
    - open_data_reader
  gen3implicit:
    policies:
    - all_programs_reader
    - open_data_reader
authz:
  all_users_policies:
  - open_data_reader
  - sower
  anonymous_policies:
  - open_data_reader

  groups:
  - name: 'developers'
    policies:
    - 'all_programs_reader'
    users: {}

  - name: 'data_submitters'
    policies:
    - 'all_programs_writer'
    - 'services.sheepdog-admin'
    - 'data_upload'
    users: {}

  - name: 'gen3_admins'
    policies:
    - 'all_programs_reader'
    - 'workspace'
    - 'prometheus'
    - 'sower'
    - 'data_upload'
    - 'indexd_admin'
    users: {}

  - name: 'gen3_developers'
    policies:
    - 'all_programs_reader'
    - 'workspace'
    - 'prometheus'
    - 'sower'
    users: {}

  resources:
  - name: data_file
  - name: workspace
  - name: prometheus
  - name: sower
  - name: open
  - description: commons /mds-admin
    name: mds_gateway
  - name: services
    subresources:
    - name: sheepdog
      subresources:
      - name: submission
        subresources:
        - name: program
        - name: project
  - name: programs
    subresources:
    - name: tutorial
    - name: open_access
      subresources:
      - name: projects
        subresources:
        - name: 1000Genomes
  policies:
  - description: ''
    id: open_data_reader
    resource_paths:
    - /open
    - /programs/tutorial
    - /programs/open_access
    role_ids:
    - guppy_reader
    - fence_reader
    - peregrine_reader
    - sheepdog_reader
  - description: full access to indexd API
    id: indexd_admin
    resource_paths:
    - /programs
    role_ids:
    - indexd_admin
  - description: ''
    id: open_data_admin
    resource_paths:
    - /open
    - /programs/tutorial
    - /programs/open_access
    role_ids:
    - creator
    - guppy_reader
    - fence_reader
    - peregrine_reader
    - sheepdog_reader
    - updater
    - deleter
    - storage_writer
  - description: ''
    id: all_programs_reader
    resource_paths:
    - /programs
    role_ids:
    - guppy_reader
    - fence_reader
    - peregrine_reader
    - sheepdog_reader
  - id: 'all_programs_writer'
    description: ''
    role_ids:
    - 'creator'
    - 'updater'
    - 'storage_writer'
    resource_paths: ['/programs']
  - description: upload raw data files to S3 (for new data upload flow)
    id: data_upload
    resource_paths:
    - /data_file
    role_ids:
    - file_uploader
  - description: be able to use workspace
    id: workspace
    resource_paths:
    - /workspace
    role_ids:
    - workspace_user
  - description: be able to use prometheus
    id: prometheus
    resource_paths:
    - /prometheus
    role_ids:
    - prometheus_user
  - description: be able to use sower job
    id: sower
    resource_paths:
    - /sower
    role_ids:
    - sower_user
  - description: be able to use metadata service
    id: mds_admin
    resource_paths:
    - /mds_gateway
    role_ids:
    - mds_user
  - description: CRUD access to programs and projects
    id: services.sheepdog-admin
    resource_paths:
    - /services/sheepdog/submission/program
    - /services/sheepdog/submission/project
    role_ids:
    - sheepdog_admin
  roles:
  - id: file_uploader
    permissions:
    - action:
        method: file_upload
        service: '*'
      id: file_upload
  - id: indexd_admin
    permissions:
    - action:
        method: '*'
        service: indexd
      id: indexd_admin
  - id: workspace_user
    permissions:
    - action:
        method: access
        service: jupyterhub
      id: workspace_access
  - id: prometheus_user
    permissions:
    - action:
        method: access
        service: prometheus
      id: prometheus_access
  - id: sower_user
    permissions:
    - action:
        method: access
        service: job
      id: sower_access
  - description: ''
    id: admin
    permissions:
    - action:
        method: '*'
        service: '*'
      id: admin
  - description: ''
    id: creator
    permissions:
    - action:
        method: create
        service: '*'
      id: creator
  - description: ''
    id: guppy_reader
    permissions:
    - action:
        method: read
        service: 'guppy'
      id: guppy_reader
  - description: ''
    id: fence_reader
    permissions:
    - action:
        method: read
        service: 'fence'
      id: fence_reader
    - action:
        method: read-storage
        service: 'fence'
      id: fence_storage_reader
  - description: ''
    id: peregrine_reader
    permissions:
    - action:
        method: read
        service: 'peregrine'
      id: peregrine_reader
  - description: ''
    id: sheepdog_reader
    permissions:
    - action:
        method: read
        service: 'sheepdog'
      id: sheepdog_reader
  - description: ''
    id: updater
    permissions:
    - action:
        method: update
        service: '*'
      id: updater
  - description: ''
    id: deleter
    permissions:
    - action:
        method: delete
        service: '*'
      id: deleter
  - description: ''
    id: storage_writer
    permissions:
    - action:
        method: write-storage
        service: '*'
      id: storage_creator
  - id: mds_user
    permissions:
    - action:
        method: access
        service: mds_gateway
      id: mds_access
  - description: sheepdog admin role for program project crud
    id: sheepdog_admin
    permissions:
    - action:
        method: '*'
        service: sheepdog
      id: sheepdog_admin_action
users: {}
EOM
    gen3 secrets sync 'setup access-backend default user.yaml'
  fi
}

if [[ -f "$(gen3_secrets_folder)/creds.json" && -z "$JENKINS_HOME" ]]; then
  if ! setup_access_backend; then
    gen3_log_err "kube-setup-access-backend bailing out - failed setup"
    exit 1
  fi
fi

gen3 roll access-backend
g3kubectl apply -f "${GEN3_HOME}/kube/services/access-backend/access-backend-service.yaml"

if [[ -z "$GEN3_ROLL_ALL" ]]; then
  gen3 kube-setup-networkpolicy
  gen3 kube-setup-revproxy
fi

gen3_log_info "The access-backend service has been deployed onto the kubernetes cluster"
