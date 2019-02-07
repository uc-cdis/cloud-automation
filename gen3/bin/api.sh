#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"


help() {
  gen3 help gitops
}

gen3_access_token() {
  local username
  username="$1"
  if [[ -z "$username" ]]; then
    help
    return 1
  fi
  g3kubectl exec $(gen3 pod fence) -- fence-create token-create --scopes openid,user,fence,data,credentials,google_service_account --type access_token --exp 3600 --username ${username} | tail -1
  return 0
}

gen3_new_project() {
  echo "ERROR: not yet implemented"
  return 0
}

gen3_new_program() {
  echo "ERROR: not yet implemented"
  return 0
}


gen3_indexd_post_folder_help() {
  cat - <<EOM
  gen3 indexd-post-folder [folder]:
      Post the .json files under the given folder to indexd
      in the current environment: $DEST_DOMAIN
      Note - currently only works with new records - does not
         attempt to update existing records.
EOM
  return 0
}

gen3_indexd_post_folder() {
  local DEST_DOMAIN
  local DEST_DIR
  local INDEXD_USER
  local INDEXD_SECRET

  DATA_DIR="$1"

  if [[ -z "${DATA_DIR}" || "${DATA_DIR}" =~ ^-*h(elp)?$ ]]; then
    gen3_indexd_post_folder_help
    return 0
  fi

  if [[ ! -d "${DATA_DIR}" ]]; then
    echo -e "$(red_color "ERROR: ") DATA_DIR, ${DATA_DIR}, does not exist"
    gen3_indexd_post_folder_help
    return 1
  fi

  DEST_DOMAIN=$(g3kubectl get configmap global -o json | jq -r '.data.hostname')
  INDEXD_USER=gdcapi
  # grab the gdcapi indexd password from sheepdog creds
  INDEXD_SECRET="$(g3kubectl get secret sheepdog-creds -o json | jq -r '.data["creds.json"]' | base64 --decode | jq -r '.indexd_password')"

  ls -1f "${DATA_DIR}" | while read -r name; do 
    if [[ $name =~ .json$ ]]; then
      echo $name; 
      curl -i -u "${INDEXD_USER}:$INDEXD_SECRET" -H "Content-Type: application/json" -d @"$DATA_DIR/$name" "https://${DEST_DOMAIN}/index/index/"
      echo --------------------; 
      echo ---------------; 
    fi
  done
}

#---------- main

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  # Support sourcing this file for test suite
  command="$1"
  shift
  case "$command" in
    "indexd-post-folder")
      gen3_indexd_post_folder "$@"
      ;;
    "access-token")
      gen3_access_token "$@"
      ;;
    "new-program")
      gen3_new_program "$@"
      ;;
    "new-project")
      gen3_new_project "$@"
      ;;
    *)
      help
      ;;
  esac
fi
