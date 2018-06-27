#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

DEST_DOMAIN=$(g3kubectl get configmap global -o json | jq -r '.data.hostname')

help() {
  cat - <<EOM
  gen3 indexd-post-folder [folder]:
      Post the .json files under the given folder to indexd
      in the current environment: $DEST_DOMAIN
      Note - currently only works with new records - does not
         attempt to update existing records.
EOM
  return 0
}

DATA_DIR="$1"

if [[ -z "${DATA_DIR}" || "${DATA_DIR}" =~ ^-*h(elp)? ]]; then
  help
  exit 0
fi

if [[ ! -d "${DATA_DIR}" ]]; then
  echo -e "$(red_color "ERROR: ") DATA_DIR, ${DATA_DIR}, does not exist"
  help
  exit 1
fi

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
