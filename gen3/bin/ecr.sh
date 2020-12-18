#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

# constants -----------------------

repoList=(
arborist
fence
indexd
peregrine
pidgin
nginx
sheepdog
data-portal
gen3-spark
tube
guppy
sower
hatchery
workspace-token-service
manifestservice
gen3-statics
metadata-service
requestor
)
# ambassador
#repoList=( fence )

accountList=(
053927701465
199578515826
222487244010
236714345101
258867494168
302170346065
345060017512
446046036926
454671780472
474789003679
504226487987
562749638216
584476192960
636151780898
662843554732
663707118480
728066667777
813684607867
830067555646
895962626746
980870151884
)

principalStr=""
for it in "${accountList[@]}"; do
  principalStr="${principalStr},\"arn:aws:iam::${it}:root\""
done

policy="$(cat - <<EOM
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Sid": "AllowCrossAccountPull",
            "Effect": "Allow",
            "Principal": {
                "AWS": [ ${principalStr#,} ]
            },
            "Action": [
               "ecr:GetAuthorizationToken",
               "ecr:BatchCheckLayerAvailability",
               "ecr:GetDownloadUrlForLayer",
               "ecr:BatchGetImage"
            ]
        }
    ]
}
EOM
)";

if ! jq -r . <<< "$policy" > /dev/null; then
  gen3_log_err "failed validating ecr repo policy: $policy"
  exit 1
fi

ecrReg="707767160287.dkr.ecr.us-east-1.amazonaws.com"

# lib -------------------------------

gen3_ecr_login() {
  if gen3_time_since ecr-login is 36000; then
    # re-authenticate every 10 hours
    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin "707767160287.dkr.ecr.us-east-1.amazonaws.com" 1>&2 || exit 1
  fi
}

gen3_quay_login() {
  if [[ -f ~/Gen3Secrets/quay/login ]]; then
    if gen3_time_since quay-login is 36000; then
      cat ~/Gen3Secrets/quay/login | docker login --username cdis+gen3 --password-stdin quay.io
    fi
  else 
    gen3_log_err "Place credentials for the quay robot account (cdis+gen3) in this file ~/Gen3Secrets/quay/login"
    exit 1
  fi
}

#
# Copy a docker image from one repo to another
#
# @param srcTag
# @param destTag
#
gen3_ecr_copy_image() {
  local srcTag="$1"
  local destTag="$2"
  if [[ "$destTag" == *"quay.io"* ]]; then 
    gen3_quay_login || return 1
  else
    gen3_ecr_login || return 1
  fi
  if [[ $# -lt 2 || -z "$srcTag" || -z "$destTag" ]]; then
    gen3_log_err "use: gen3_ecr_copy_image source dest"
    return 1
  fi
  shift
  shift
  (docker pull "$srcTag" && \
    docker tag "$srcTag" "$destTag" && \
    docker push "$destTag"
  ) || return 1
  # save disk space
  docker image rm "$srcTag" "$destTag"
  return 0
}

#
# Sync the given tag from quay to ecr
#
# @param repoName
gen3_ecr_quay_sync() {
  local repoName="$1"
  shift
  local tagName="$1"

  if ! shift; then
    gen3_log_err "use: gen3_ecr_quay_sync repoName tagName"
    return 1
  fi
  repoName="${repoName##*/}"
  local srcImage="quay.io/cdis/$repoName:$tagName"
  local destImage="$ecrReg/gen3/$repoName:$tagName"
  gen3_ecr_copy_image "$srcImage" "$destImage"
}

gen3_dh_quay_sync () {
  local srcImage="$1"
  shift
  local  destImage="$1"

  if ! shift; then
    gen3_log_err "use: gen3_dh_quay_sync srcImage destImage"
    return 1
  fi
  gen3_ecr_copy_image "$srcImage" "$destImage"
}

#
# Update the policy on the specified repository.
# For example - when a new CTDS client account needs access
#
# @param repoName
#
gen3_ecr_update_policy() {
  local repoName="$1"
  shift || return 1
  aws ecr set-repository-policy --repository-name "$repoName" --policy-text "$policy"
}


#
# List the `gen3/` repository names (in the current account)
#
gen3_ecr_repolist() {
  aws ecr describe-repositories | jq -r '.repositories[] | .repositoryName' | grep '^gen3/'
}


gen3_ecr_registry() {
  echo "$ecrReg"
}

# main -----------------------

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  # Support sourcing this file for test suite
  command="$1"
  shift
  case "$command" in
    "list")
      gen3_ecr_repolist "$@"
      ;;
    "quaylogin")
      gen3_quay_login "$@"
      ;;
    "login")
      gen3_ecr_login "$@"
      ;;
    "update-policy")
      gen3_ecr_update_policy "$@"
      ;;
    "copy")
      gen3_ecr_copy_image "$@"
      ;;
    "registry")
      gen3_ecr_registry "$@"
      ;;
    "quay-sync")
      gen3_ecr_quay_sync "$@"
      ;;
    "dh-quay")
      gen3_dh_quay_sync "$@"
      ;;
    *)
      gen3 help ecr
      exit 1
      ;;
  esac
fi
