#
# Unified entrypoint for gitops and manifest related commands
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

help() {
  gen3 help gitops
}

#
# Internal util for checking for differences between manifest-global
# configmap and manifest.json
#
# @param keyName
# @returns echos true if diff found, false if no diff
#
_check_manifest_global_diff() {
  local keyName=$1
  if [[ -z "$keyName" ]]; then
    gen3_log_err "_check_manifest_global_diff: keyName argument missing"
    return 1;
  fi

  local oldVal
  if g3kubectl get configmap manifest-global > /dev/null; then
    oldVal=$(g3kubectl get configmap manifest-global -o jsonpath={.data.${keyName}})
  else
    oldVal=$(g3kubectl get configmap global -o jsonpath={.data.${keyName}})
  fi
  local newVal=$(g3k_config_lookup ".global.${keyName}")
  
  if [[ ( -z "${newVal}" ) || ( "${newVal}" == "null" ) ]]; then
    gen3_log_warn "Unable to find ${keyName} in manifest.json; skipping for diff"
    echo "false"
  elif [[ "${oldVal}" != "${newVal}" ]]; then
    echo "true"
  else
    echo "false"
  fi
}

#
# Internal uptil for checking for differences in cloud-automation 
# basicallt checking if through git 

_check_cloud-automation_changes() {

  #cd ~/cloud-automation
  if git diff-index --quiet HEAD --; then
    # Should the repo has no changes, let's just pull, because why not
    git pull > /dev/null 2>&1
    echo "false"
  else
    echo "true"
  fi
}

#
# Check the branch cloud-automation is on
#
_check_cloud-automation_branch() {

  local branch
  branch=$(git rev-parse --abbrev-ref HEAD)
  echo "${branch}"
}


#
# General tfplan function that depending on the value of next argument
# it'll determine which subfuntion to send the payload
#
gen3_run_tfplan() {

  local message
  local sns_topic
  local module
  local changes
  local current_branch
  local quiet
  local apply
  

  args=("$@")
  ELEMENTS=${#args[@]}
  for (( i=0;i<$ELEMENTS;i++)); do 
    #echo ${args[${i}]} 
    if [ "${args[${i}]}" == "vpc" ] || [ "${args[${i}]}" == "eks" ] || [ "${args[${i}]}" == "management-logs" ];
    then
      module="${args[${i}]}"
    elif [ "${args[${i}]}" == "apply" ];
    then
      apply="${args[${i}]}"
    elif [ "${args[${i}]}" == "quiet" ];
    then
      quiet="${args[${i}]}"
    fi
  done

  sns_topic="arn:aws:sns:us-east-1:433568766270:planx-csoc-alerts-topic"
  #sns_topic="arn:aws:sns:us-east-1:433568766270:fauzi-alert-channel"


  (
    cd ~/cloud-automation
    changes=$(_check_cloud-automation_changes)
    #changes="false"
    current_branch=$(_check_cloud-automation_branch)
    #current_branch="master"

    #echo ${changes}

    if [[ ${changes} == "true" ]];
    then
      #local files_changes
      #changes="$(git diff-index --name-only HEAD --)"
      message=$(mktemp -p "$XDG_RUNTIME_DIR" "tmp_plan.XXXXXX")
      echo "${vpc_name} has uncommited changes for cloud-automation:" > ${message}
      echo "For branch ${current_branch}" >> ${message}
      git diff-index --name-only HEAD -- >> ${message} 2>&1
    elif [[ ${changes} == "false" ]];
    then
      # checking for the result of _check_cloud-automation_changes just in case it came out empty
      # for whatever reson

      if [[ ${current_branch} == "master" ]];
      then
        message=$(_gen3_run_tfplan_x ${module} ${apply})
      else
        message=$(mktemp -p "$XDG_RUNTIME_DIR" "tmp_plan.XXXXXX")
        echo "cloud-automation for ${vpc_name} is not on the master branch:" > ${message}
        echo "Branch ${current_branch}" >> ${message}
      fi
    fi

    if [ -n "${message}" ];
    then
      if ! [ -n "${quiet}" -a "${quiet}" == "quiet" ];
      then
        aws sns publish --target-arn ${sns_topic} --message file://${message} > /dev/null 2>&1
      else
        cat ${message}
      fi
      rm ${message}
    fi
  )

}


#
# Apply changes picked up by tfplan
#
gen3_run_tfapply() {
  local module=$1
  gen3_run_tfplan "$@" "quiet" "apply"
}

#
# Run a terraform plan and output a short version of the plan
# 
#
_gen3_run_tfplan_x(){
  local plan
  local slack_hook
  local tempFile
  local output
  local apply
  local module
  local profile
  local vpc_module

  apply=$2
  module=$1
  profile=$(grep profile ~/.aws/config | awk '{print $2}' | cut -d] -f1 |head -n1)

  if [ -n ${module} ] && [ "${module}" == "vpc" ];
  then
    vpc_module=${vpc_name}
  elif [ -n ${module} ];
  then
    vpc_module="${vpc_name}_${module}"
  else
    gen3_log_error "There has been an error running tfplan, no module has been selected"
    exit 2
  fi
    
  gen3_log_info "Entering gen3 workon ${profile} ${vpc_module}"
  gen3 workon ${profile} ${vpc_module} > /dev/null 2>&1

  output="$(gen3 tfplan)"
  plan=$(echo -e "${output}" |grep "Plan")

  gen3_log_info ${plan}
  if [ -n "${plan}" ];
  then
    tempFile=$(mktemp -p "$XDG_RUNTIME_DIR" "tmp_plan.XXXXXX")
    echo "${vpc_name}_${module} has unapplied plan:" > ${tempFile}
    echo -e "${plan}"| sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" >> ${tempFile}
    if [ -n "$apply" -a "$apply" == "apply" ];
    then
      echo -e "${output}" >> ${tempFile}
      gen3 tfapply >> ${tempFile} 2>&1
    else
      echo "No apply this time" >> ${tempFile}
    fi
  fi
  #gen3_log_info "${tempFile}"
  echo "${tempFile}"
}


# command to update dictionary URL and image versions
#
gen3_gitops_sync() {
  g3k_manifest_init
  local dict_roll=false
  local versions_roll=false
  local portal_roll=false
  local etl_roll=false
  local covid_cronjob_roll=false
  local fence_roll=false
  local slack=false
  local tmpHostname
  local resStr
  local color
  local dictAttachment
  local versionsAttachment
  local commonsManifestDir
  local portalDiffs
  local fenceDiffs
  local etlDiffs

  if [[ $1 = '--slack' ]]; then
    if [[ "${slackWebHook}" == 'None' || -z "${slackWebHook}" ]]; then
      slackWebHook=$(g3kubectl get configmap global -o jsonpath={.data.slack_webhook})
    fi
    if [[ "${slackWebHook}" != 'None' && ! -z "${slackWebHook}" ]]; then
      slack=true
    else
      echo "WARNING: slackWebHook is None or doesn't exist; not sending results to Slack"
    fi
  fi

  # dictionary URL check
  if g3kubectl get configmap manifest-global; then
    oldUrl=$(g3kubectl get configmap manifest-global -o jsonpath={.data.dictionary_url})
  else
    oldUrl=$(g3kubectl get configmap global -o jsonpath={.data.dictionary_url})
  fi
  newUrl=$(g3k_config_lookup ".global.dictionary_url")
  echo "old Url is: $oldUrl"
  echo "new Url is: $newUrl"
  if [[ -z $newUrl ]]; then
    echo "Could not get new url from manifest, maybe the g3k functions are broken. Skipping dictionary update"
  elif [[ $newUrl == $oldUrl ]]; then
    echo "Dictionary URLs are the same (and not blank), skipping dictionary update"
  else
    echo "Dictionary URLs are different, updating dictionary"
    if [[ $oldUrl = null ]]; then
      echo "Could not get current url from manifest-global configmap, applying new url from manifest and rolling"
    fi
    dict_roll=true
  fi

  # covid19-cronjob image check 
  gen3_log_info "checking cronjobs versions."
  gen3_log_info "checking if env manifest consists covid19-notebook-etl service"
  if g3k_config_lookup '.versions."covid19-notebook-etl"'; then
    gen3_log_info "it does ... !"
    if g3kubectl get configmap manifest-versions; then
      oldImage=$(g3kubectl get configmap manifest-versions -o=json | jq '.data."covid19-notebook-etl"' | tr -d \" )
    fi
    newImage=$(g3k_config_lookup '.versions."covid19-notebook-etl"')
    gen3_log_info "old image is: $oldImage"
    gen3_log_info "new image is: $newImage"
    if [[ $newImage == $oldImage ]]; then
      gen3_log_info "The images are same, skipping covid19-etl-cronjob update"
    else
      gen3_log_info "Images are different, updating cronjobs"
      covid_cronjob_roll=true
    fi
  else
    gen3_log_info "it doesn't ... skipping covid19-notebook-etl roll!"
  fi


  # image versions check
  if g3kubectl get configmap manifest-versions; then
    oldJson=$(g3kubectl get configmap manifest-versions -o=json | jq ".data")
  fi
  echo "old JSON is: $oldJson"
  newJson=$(g3k_config_lookup ".versions")
  # Make sure the script exits if newJSON contains invalid JSON 
  if [ $? -ne 0 ]; then
    echo "Error: g3k_config_lookup command failed- invalid JSON"
    exit 1
  else
    echo "new JSON is: $newJson"
  fi
  if [[ -z $newJson ]]; then
    echo "Manifest does not have versions section. Unable to get new versions, skipping version update."
  elif [[ -z $oldJson ]]; then
    echo "Configmap manifest-versions does not exist, cannot extract old versions. Using new versions."
    versions_roll=true
  else 
    changeFlag=0
    for key in $(jq -r "keys[]" <<< "$newJson"); do
      newVersion=$(jq ".\"$key\"" <<< "$newJson")
      oldVersion=$(jq ".\"$key\"" <<< "$oldJson") 
      echo "$key old Version is: $oldVersion"
      echo "$key new Version is: $newVersion"
      if [ "$oldVersion" !=  "$newVersion" ]; then
        echo "$key versions are not the same"
        changeFlag=1
      fi
    done
    if [[ changeFlag -eq 0 ]]; then
      echo "Versions are the same, skipping version update."
    else
      echo "Versions are different, updating versions."
      versions_roll=true
    fi
  fi

  # portal directory config check
  commonsManifestDir=$(dirname $(g3k_manifest_path))
  local defaultsDir="${GEN3_HOME}/kube/services/portal/defaults"
  if [[ ! -d "${commonsManifestDir}/portal" ]]; then
    gen3_log_info "Portal directory not found, skipping portal update"
  else
    # for each file in the portal defaults dir...
    #   if file not found in commons's portal dir
    #     use default file for comparison
    #   else
    #     use commons's file in manifest/portal dir
    #
    #   if file not in secret
    #     roll portal
    #   else if comparison file and secret are different
    #     roll portal

    local filename
    local secretsFile
    local comparingFile
    local diffMsg
    for defaultFilepath in $(find "${defaultsDir}/" -name "gitops*" -type f); do
      diffMsg=""
      filename=$(basename ${defaultFilepath})
      commonsFilepath="${commonsManifestDir}/portal/$filename"
      secretsFile=$(g3kubectl get secret portal-config -o json | jq -r '.data."'"${filename}"'"')

      # get file contents from default file or commons's file
      if [[ ! -f "${commonsFilepath}" ]]; then
        comparingFile=$(base64 $defaultFilepath -w 0)
        gen3_log_info "Comparing default portal file $defaultFilepath"
      else
        comparingFile=$(base64 $commonsFilepath -w 0)
        gen3_log_info "Comparing commons's portal file $commonsFilepath"
      fi

      # check for a diff
      if [[ "${secretsFile}" = null ]]; then
        diffMsg="Diff in portal/${filename} - file not found in secret"
      elif [[ "${secretsFile}" != "${comparingFile}" ]]; then
        diffMsg="Diff in portal/${filename} - difference between file and secret"
      fi
      if [[ -n "${diffMsg}" ]]; then
        portalDiffs="${portalDiffs} \n${diffMsg}"
        gen3_log_info "$diffMsg"
        portal_roll=true
      fi
    done
  fi

  # portal manifest config check
  if [[ "$(_check_manifest_global_diff portal_app)" == "true" ]]; then
    gen3_log_info "Diff in manifest global.portal_app"
    portalDiffs="$portalDiffs \nDiff in manifest global.portal_app"
    portal_roll=true
  fi
  if [[ "$(_check_manifest_global_diff tier_access_level)" == "true" ]]; then
    gen3_log_info "Diff in manifest global.tier_access_level"
    portalDiffs="$portalDiffs \nDiff in manifest global.tier_access_level"
    portal_roll=true
  fi

  # fence manifest directory config check
  if [[ ! -f "${commonsManifestDir}/manifests/fence/fence-config-public.yaml" ]]; then
    gen3_log_info "Fence Manifests file not found, skipping fence update"
  else
    local fenceConfigFilename
    local fenceConfigMapFile
    local fenceCommonsFilepath
    local fenceComparingFile
    local fenceDiffMsg
    FenceDiffMsg=""
    fenceConfigFilename="fence-config-public.yaml"
    fenceCommonsFilepath="${commonsManifestDir}/manifests/fence/$fenceConfigFilename"
    fenceConfigMapFile=$(g3kubectl get cm manifest-fence -o json | jq -r '.data."'"$fenceConfigFilename"'"' | tr -d '\n')
    # get file contents from default file or commons's file
    fenceComparingFile=$(cat $fenceCommonsFilepath | tr -d '\n')
    # check for a diff
    if [[ "${fenceConfigMapFile}" = null ]]; then
      FenceDiffMsg="Diff in fence-config/${fenceConfigFilename} - file not found in secret"
    elif [[ "${fenceConfigMapFile}" != "${fenceComparingFile}" ]]; then
      FenceDiffMsg="Diff in fence-config/${fenceConfigFilename} - difference between file and secret"
    fi
    if [[ -n "${FenceDiffMsg}" ]]; then
      fenceDiffs="${fenceDiffs} \n${FenceDiffMsg}"
      gen3_log_info "$FenceDiffMsg"
      fence_roll=true
    fi
  fi
  if [[ ! -f "${commonsManifestDir}/etlMapping.yaml" ]]; then
    gen3_log_info "etl mapping file not found, skipping etl update"
  else
    local filename
    local configMapFile
    local comparingFile
    local diffMsg
    diffMsg=""
    filename="etlMapping.yaml"
    commonsFilepath="${commonsManifestDir}/$filename"
    configMapFile=$(g3kubectl get cm etl-mapping -o json | jq -r '.data."'"$filename"'"' | tr -d '\n')
    # get file contents from default file or commons's file
    comparingFile=$(cat $commonsFilepath | tr -d '\n')
    # check for a diff
    if [[ "${configMapFile}" = null ]]; then
      diffMsg="Diff in etlMapping/${filename} - file not found in secret"
    elif [[ "${configMapFile}" != "${comparingFile}" ]]; then
      diffMsg="Diff in etlMapping/${filename} - difference between file and secret"
    fi
    if [[ -n "${diffMsg}" ]]; then
      etlDiffs="${etlDiffs} \n${diffMsg}"
      gen3_log_info "$diffMsg"
      etl_roll=true
    fi
  fi

  echo "DRYRUN flag is: $GEN3_DRY_RUN"
  if [ "$GEN3_DRY_RUN" = true ]; then
    echo "DRYRUN flag detected, not rolling"
    gen3_log_info "dict_roll: $dict_roll; versions_roll: $versions_roll; portal_roll: $portal_roll; etl_roll: $etl_roll; fence_roll: $fence_roll"
  else
    if [[ ( "$dict_roll" = true ) || ( "$versions_roll" = true ) || ( "$portal_roll" = true )|| ( "$etl_roll" = true )  || ( "$covid_cronjob_roll" = true ) || ("fence_roll" = true) ]]; then
      echo "changes detected, rolling"
      # run etl job before roll all so guppy can pick up changes
      if [[ "$etl_roll" = true ]]; then
          gen3 update_config etl-mapping "$(gen3 gitops folder)/etlMapping.yaml"
          gen3 job run etl --wait ETL_FORCED TRUE
      fi

      # update fence ConfigMap before roll-all
      if [[ "$fence_roll" = true ]]; then
          gen3 update_config manifest-fence "$(gen3 gitops folder)/manifests/fence/fence-config-public.yaml"
      fi

      if [[ "$covid_cronjob_roll" = true ]]; then
        if g3k_config_lookup '.global."covid19_data_bucket"'; then
          s3Bucket_url=$(kubectl get configmap manifest-global -o json | jq .data.covid19_data_bucket | tr -d \" )
          echo "##S3BUCKET_URL : ${s3Bucket_url}"
          gen3 job run covid19-notebook-etl-cronjob S3_BUCKET s3://${s3Bucket_url}
        else 
          echo "The global block does not contain the covid19 databucket URL"
          echo "not running the covid19-notebook-etl job ..."
        fi
      fi    
      gen3 kube-roll-all
      rollRes=$?
      # send result to slack
      if [[ $slack = true ]]; then
        tmpHostname=$(gen3 api hostname)
        resStr="SUCCESS"
        color="#1FFF00"
        if [[ $rollRes != 0 ]]; then
          resStr="FAILURE"
          color="#FF0000"
        fi
        if [[ "$dict_roll" = true ]]; then
          dictAttachment="\"title\": \"New Dictionary\", \"text\": \"${newUrl}\", \"color\": \"${color}\""
        fi
        if [[ "$versions_roll" = true ]]; then
          versionsAttachment="\"title\": \"New Versions\", \"text\": \"$(echo $newJson | sed s/\"/\\\\\"/g | sed s/,/,\\n/g)\", \"color\": \"${color}\""
        fi
        if [[ "$portal_roll" = true ]]; then
          portalAttachment="\"title\": \"Portal Diffs\", \"text\": \"${portalDiffs}\", \"color\": \"${color}\""
        fi
        if [[ "$fence_roll" = true ]]; then
          fenceAttachment="\"title\": \"Fence Diffs\", \"text\": \"${fenceDiffs}\", \"color\": \"${color}\""
        fi
        if [[ "$etl_roll" = true ]]; then
          etlAttachment="\"title\": \"ETL Diffs\", \"text\": \"${etlDiffs}\", \"color\": \"${color}\""
        fi
        if [[ "$covid_cronjob_roll" = true ]]; then
          covidAttachment="\"title\": \"Covid Cronjob update\", \"text\": \"Updated covid19 notebook etl version\", \"color\": \"${color}\""
        fi
        curl -X POST --data-urlencode "payload={\"text\": \"Gitops-sync Cron: ${resStr} - Syncing dict and images on ${tmpHostname}\", \"attachments\": [{${dictAttachment}}, {${versionsAttachment}}, {${portalAttachment}}, {${fenceAttachment}}, {${etlAttachment}}, {${covidAttachment}}]}" "${slackWebHook}"
      fi
    else
      echo "no changes detected, not rolling"
    fi
  fi
}


#
# Run `gen3 gitops sync` against a remote ssh target
#
gen3_gitops_rsync() {
  local target
  target="$1"
  if [[ -z "$1" ]]; then
    echo -e "$(red_color "ERROR: gen3 gitops rsync user@host")"
    return 1
  fi
  if ! ssh "$target" "bash -c 'cd cloud-automation && git checkout master && git pull && cd ../cdis-manifest && git checkout master && git pull'"; then
    echo -e "$(red_color "ERROR: could not update cloud-automation or cdis-manifest at $target")"
    return 1
  fi
  ssh "$target" "bash -ic 'gen3 gitops sync'"
}

#
# Get the local manifest and cloud-automation folders in sync with github
#
gen3_gitops_enforcer() {
  local manifestDir
  local manifestPath
  local today

  manifestPath=$(g3k_manifest_path)
  if [[ $? -ne 0 || ! -f "$manifestPath" ]]; then
    return 1
  fi
  manifestDir="$(dirname "$manifestPath")"
  today="$(date -u +%Y%m%d)"
  weekAgo="$(date -d "@$(($(date +%s) - 60*60*24*7))" +%Y%m%d)"

  for syncDir in "$manifestDir/.." "$GEN3_HOME"; do
    ( # subshell for cd
      echo "Syncing $syncDir with git master" 1>&2
      cd "${syncDir}"

      ( # subshell cd - erase old backups
        cd backups
        for oldDir in $(ls .); do
          if [[ "$oldDir" =~ ^[0-9]+$ && $oldDir -lt $weekAgo ]]; then
            echo "Erasing old backup $(pwd)/$oldDir" 1>&2
            /bin/rm -rf "$oldDir"
          fi
        done
      )
      if [[ ! -d "backups/$today" ]]; then
        # only take one backup each day ...
        mkdir -p "backups/$today"
        mv $(/bin/ls . | grep -v backups) "backups/$today/"
      fi
      git checkout .
      git checkout -f master
      git pull --prune
      git reset --hard origin/master
    )
  done
}

#
# g3k command to create configmaps from manifest
#
gen3_gitops_history() {
  local manifestDir
  if [[ $# -gt 0 ]]; then
    manifestDir="$1"
  fi  
  ( # subshell - can cd and set globals
    set -e  # fail on any weirdness

    if [[ -z "$manifestDir" ]]; then
      manifestPath=$(g3k_manifest_path)
      manifestDir="$(dirname "$manifestPath")"
    fi
    cd "$manifestDir"
    git log -p -w --full-diff .
  )
}


#
# Create a manifest- configmap from the given json blob.
# Pass additional arguments through to kubectl
#
# @param configMapName
# @param json string to process - ignored if ""
# @param varargs other arguments to pass to kubectl create configmap
#
gen3_gitops_json_to_configmap() {
  local argList=()
  local configMapName="$1"
  shift || return 1
  local json="$1"
  shift || return 1
  if [[ $# -gt 0 ]]; then
    argList+=("$@")
  fi
  if [[ -n "$json" ]]; then
    local key
    local value
    local keyList
    # make sure it's valid json object or array
    keyList="$(jq -r '. | keys[]' <<< "$json")" || return 1
    # convert to array, only consider keys that start with a letter
    if keyList=( $(grep '^[a-zA-Z]' <<< "$keyList") ); then
      for key in "${keyList[@]}"; do
        value="$(jq -r --arg key "$key" '.[$key]' <<< "$json")"
        if [[ -n "$value" ]]; then
          argList+=("--from-literal" "$key=$value")
        fi
      done
    fi
    argList+=("--from-literal" "json=$json")
  fi
  gen3_log_info "create configmap $configMapName"
  # for debugging - gen3_log_info "g3kubectl create configmap $configMapName ${argList[@]}"
  g3kubectl create configmap "$configMapName" "${argList[@]}"
}


#
# Generate manifest entries for the files in the given folder
#
# @param folder to pull into manifest configmap
#
gen3_gitops_configmap_folder() {
  local folder="$1"
  shift || return 1
  if [[ -n "$folder" && -d "$folder" && "$(basename "$folder")" =~ ^[0-9A-Za-z] ]]; then
    local key="$(basename "$folder")"
    local cMapName="manifest-$key"
    local gotData=false
    local key2
    local json=""
    local folderEntry
    local argList=()
    for folderEntry in "$folder/"*; do
      if [[ -f "$folderEntry" ]]; then
        key2="$(basename "$folderEntry")"
        gotData=true
        argList+=("--from-file=$folderEntry")
        if [[ "$key2" == "${key}.json" ]]; then
          # to help transition data out of the master manifest.json
          json="$(cat "$folderEntry")"
        fi
      fi
    done
    if [[ "$gotData" == "true" ]]; then
      gen3_gitops_json_to_configmap "manifest-$key" "$json" "${argList[@]}"
      return $?
    fi
  fi
  gen3_log_err "invalid manifest folder: $folder"
  return 1
}

#
# Get the sorted list of all the configmap keys from
# manifest.json, manifests/ folder, and gen3/lib/manifestDefaults/
#
# @param manifestFolder optional - defaults to (dirname g3k_manifest_path)
gen3_gitops_configmaps_list() {
  local manifestFolder="$1"
  shift || manifestFolder="$(dirname $(g3k_manifest_path))"
  if ! [[ -n "$manifestFolder" && -d "$manifestFolder" && -f "$manifestFolder/manifest.json" ]]; then
    gen3_log_err "failed to establish manifest folder - $manifestFolder"
    return 1
  fi
  local keyList="$(mktemp "$XDG_RUNTIME_DIR/cfmap_list_XXXXXX")"
  # keys from manifest.json
  jq -r '. | keys[]' < "$manifestFolder/manifest.json" > "$keyList" || return $?
  # keys from manifests/ folder
  if [[ -d "$manifestFolder/manifests" ]]; then
    (cd "$manifestFolder" && find manifests -mindepth 2 -maxdepth 2 -type f | awk -F / '{ print $2 }') >> "$keyList" || return $?
  fi
  # keys from manifestDefaults/ folder
  if [[ -d "$GEN3_HOME/gen3/lib/manifestDefaults" ]]; then
    (cd "$GEN3_HOME/gen3/lib/" && find manifestDefaults -mindepth 2 -maxdepth 2 -type f | awk -F / '{ print $2 }') >> "$keyList"
  else
    gen3_log_warn "failed to find manifestDefaults folder: $GEN3_HOME/gen3/lib/manifestDefaults"
  fi
  echo "etl-mapping" >> "$keyList"
  echo "all" >> "$keyList"
  sort -u < "$keyList" | grep -v -e '^[[:space:]]*$' | grep -v '^notes$'
  rm "$keyList"
}

#
# Extract project-mapping from user.yaml for etl
#
gen3_gitops_etlconvert() {
  yq -r '[ (.users | .[] | .projects // [] | .[] | { "key": .auth_id, "value": .resource }), (.rbac.user_project_to_resource // {} | to_entries | .[]), (.authz.user_project_to_resource // {} | to_entries | .[]) ] | map(select(.value != null)) | sort_by(.key) | from_entries | { authz: { user_project_to_resource: . } }'
}

#
# g3k command to create configmaps from manifest
#
# @param folder optional parameter - if set, then scans folder for configmap
#
gen3_gitops_configmaps() {
  local manifestPath
  manifestPath=$(g3k_manifest_path)
  if [[ ! -f "$manifestPath" ]]; then
    gen3_log_err "manifest does not exist - $manifestPath"
    return 1
  fi

  if ! grep -q global $manifestPath; then
    gen3_log_err "manifest does not have global section - $manifestPath"
    return 1
  fi

  local manifestFolder
  manifestFolder="$(dirname "$manifestPath")"
  local keyList
  local deleteList
  if [[ $# -gt 0 ]]; then
    keyList=( "$@" )
    for key in "${keyList[@]}"; do
      if [[ "$key" == "etl-mapping" ]]; then
        deleteList+=( "$key" )
      else
        deleteList+=( "manifest-$key" )
      fi
    done
  else
    keyList=( $(gen3_gitops_configmaps_list) ) || return 1
    mapfile -t deleteList < <( g3kubectl get configmaps -o custom-columns=:.metadata.name --no-headers=true | grep "manifest-\|etl-" )
  fi

  local key
  local key2
  local etlPath="$manifestFolder/etlMapping.yaml"
  local cMapName
  local json
  local defaultsDir="${GEN3_HOME}/gen3/lib/manifestDefaults"
  local result=0

  # delete everything in a single call for performance
  # grab existing configmaps from k8s env 
  g3kubectl delete configmaps "${deleteList[@]}"

  for key in "${keyList[@]}"; do
    if [[ "$key" == "etl-mapping" ]]; then
      if [[ -f "$etlPath" ]]; then
        gen3_gitops_json_to_configmap "$key" "" "--from-file=${etlPath##*/}=${etlPath}"
        result=$((result + $?))
      else
        gen3_log_warn "no etl-mapping at $etlPath"
      fi
    elif [[ "$key" == "all" ]]; then
      g3kubectl create configmap manifest-all --from-literal json="$(g3k_config_lookup "." "$manifestPath")"
      result=$((result + $?))
    elif [[ -d "$manifestFolder/manifests/$key" ]]; then
      gen3_log_info "loading $key from $manifestFolder/manifests/$key"
      gen3_gitops_configmap_folder "$manifestFolder/manifests/$key"
      result=$((result + $?))
    elif json="$(jq -e -r --arg key "$key" '.[$key]' < "$manifestPath")" && [[ -n "$json" ]]; then
      gen3_log_info "loading $key from $manifestPath"
      cMapName="manifest-$key"
      gen3_gitops_json_to_configmap "$cMapName" "$json"
      result=$((result + $?))
    elif [[ -d "$defaultsDir/$key" ]]; then
      gen3_log_info "loading $key from $defaultsDir/$key"
      gen3_gitops_configmap_folder "$defaultsDir/$key"
      result=$((result + $?))
    else
      gen3_log_err "ignoring invalid manifest key: $key"
    fi
  done
  return $result
}

declare -a gen3_gitops_repolist_arr=(
  uc-cdis/arborist
  uc-cdis/fence
  uc-cdis/gen3-arranger
  uc-cdis/gen3-spark
  uc-cdis/guppy
  uc-cdis/indexd
  uc-cdis/indexs3client
  uc-cdis/docker-nginx
  uc-cdis/manifestservice
  uc-cdis/peregrine
  uc-cdis/pidgin
  uc-cdis/data-portal
  uc-cdis/sheepdog
  uc-cdis/ssjdispatcher
  uc-cdis/tube
  uc-cdis/workspace-token-service
  uc-cdis/requestor
  uc-cdis/audit-service
)

declare -a gen3_gitops_sshlist_arr=(
accountprod@account.csoc
anvilprod@anvil.csoc
dcfprod@dcfprod.csoc
staging@dcfprod.csoc
dcfqav1@dcfqa.csoc
bhcprodv2@braincommons.csoc
bloodv2@occ.csoc
cvbcommons@cvbcommons.csoc
dataguids@gtex.csoc
gtexdev@gtex.csoc
gtexprod@gtex.csoc
niaidprod@niaiddh.csoc
prodv1@kf.csoc
edcprodv2@occ-edc.csoc
ibdgc@ibdgc.csoc
ncigdcprod@ncigdc.csoc
ncicrdcdemo@ncicrdc.csoc
vadcprod@vadc.csoc
yilinxu@account.csoc
kfqa@gmkfqa.csoc
skfqa@gmkfqa.csoc
genomelprod@genomel.csoc
)

#
# List the releases for the given git repo.
# Note that this very quickly runs into rate-limiting, so cache result aggressively:
#    https://developer.github.com/v3/#rate-limiting
#
# @param --force to ignore cache
# @return echo list of top 5 semver tags in form: "repo tag1 tag2 ..."
#
gen3_gitops_repo_taglist() {
  local repoPath
  local repoList
  local url
  local cacheDir
  cacheDir="${GEN3_CACHE_DIR}/gitRepos"
  mkdir -p "$cacheDir"
  local cacheFile
  cacheFile="${cacheDir}/tagListCache.ssv"
  local useCache
  useCache=true
  local baseName

  if [[ "$1" =~ -*force ]]; then
    useCache=""
    shift
  fi
  if [[ "$1" =~ -*help ]]; then
    help
    return 1
  fi

  if [[ ! (-f "$cacheFile" && $(($(stat --format=%Y "$cacheFile")+120)) -gt $(date +%s)) ]]; then
    # cache is not fresh (2 minutes old)
    useCache=""
  fi
  if [[ -z "$useCache" ]]; then
    if [[ -f "$cacheFile" ]]; then
      rm "$cacheFile"
    fi
    # repoList="$@" - let's not do this - user can grep himself
    repoList="${gen3_gitops_repolist_arr[@]}"
    #echo "Scanning repolist: ${repoList}" 1>&2
    for repoPath in $repoList; do
      baseName="$(basename "$repoPath")"

      if [[ ! "$repoPath" =~ ./. ]]; then
        repoPath="uc-cdis/$repoPath"
      fi
      (
        cd "$cacheDir"
        result="$repoPath"
        if [[ ! -d "./$baseName" ]]; then
          git clone "https://github.com/${repoPath}.git" 1>&2
          cd "$baseName"
          git remote add ssh "git@github.com:${repoPath}.git" 1>&2
        else
          cd "$baseName"
          git fetch --prune 1>&2
        fi
        git ls-remote --tags 2> /dev/null | awk '{ str=$2; sub(/.*\//, "", str); print str }' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9_]+)?$' | sort -Vr | head -5 | (
          while read -r tag; do
            result="$result $tag"
          done
          echo "$result" >> "$cacheFile"
        )
      )
      # Querying via the API hits anonymous rate limit quickly
      #url="https://api.github.com/repos/${repoPath}/tags"
      #echo "Scanning $repoPath - $url" 1>&2
    done
  else
    echo -e "$(green_color "INFO: using cache at $cacheFile, use --force to bypass")" 1>&2
  fi
  echo "" 1>&2  # blank line
  cat "$cacheFile"
  return $?
}


#
# Generate and push a new tag.
# Requires the user to have ssh write access to the github repo.
#
# @param repoName like fence
#
gen3_gitops_repo_dotag() {
  local repoName
  repoName="$1"
  local cacheDir
  local nextVer
  nextVer="1.0.0"
  cacheDir="${GEN3_CACHE_DIR}/gitRepos/$repoName"

  if [[ -z "$repoName"  || "$repoName" =~ -*help ]]; then
    help
    return 0
  fi
  if ! (gen3_gitops_repo_taglist --force | grep "$repoName"); then
    echo -e "$(red_color "ERROR: invalid repo name: $repoName")" 1>&2
    return 1
  fi
  if [[ ! -d "$cacheDir" ]]; then
    echo -e "$(red_color "ERROR: $cacheDir does not exist")"
    return 1
  fi
  # taglist guarantees tags of form #.#.#(-...)?
  nextVer="$(gen3 gitops taglist | grep "$repoName" | awk '{ print $2 }')"
  if [[ -z "$nextVer" ]]; then
    nextVer="1.0.0"
  else
    nextVer="$(
      prefix="$(echo $nextVer | sed -e 's/[^\.]*$//')"
      patchNum="$(echo $nextVer | sed -e 's/^.*\.//' | sed -e 's/-.*$//')"
      echo "${prefix}$(($patchNum+1))"
    )"
  fi
  (
    cd "$cacheDir"
    if ! git pull --prune; then
      echo -e "$(red_color "ERROR: failed to pull latest code from github")"
      return 1
    fi
    echo "New tag: $nextVer" 1>&2
    sleep 5   # give the user a couple seconds to see the current tag list, etc
    git tag -d "$nextVer" > /dev/null 2>&1 || true
    commentFile=$(mktemp "$XDG_RUNTIME_DIR/gitco.txt.XXXXXX")
    echo "chore(tag $nextVer): save an empty file to abort" > "$commentFile"
    EDITOR="${EDITOR:-vi}"
    "${EDITOR}" "$commentFile"
    if [[ 4 -gt "$(stat "--format=%s" "$commentFile")" ]]; then
      echo -e "$(red_color "ERROR: aborting tag - empty comment")" 1>&2
      rm "$commentFile"
      return 1
    fi
    if ! git tag -a -F "$commentFile" "$nextVer"; then
      echo -e "$(red_color "git tag command failed")" 1>&2
      return 1
    fi
    rm "$commentFile"
    if git push ssh "$nextVer"; then
      # refresh taglist cache
      gen3 gitops taglist --force
    else
      echo -e "$(red_color "failed to push $nextVer tag to github")" 1>&2
      git tag -d "$nextVer"
      return 1
    fi
  )
}


gen3_gitops_repolist() {
  local name
  for name in "${gen3_gitops_repolist_arr[@]}"; do
    echo "$name"
  done
}

gen3_gitops_sshlist() {
  local name
  for name in "${gen3_gitops_sshlist_arr[@]}"; do
    echo "$name"
  done
}

#
# Get the path to the yaml file to apply for a `gen3 roll name` command.
# Supports deployment versions (ex: ...-deploy-1.0.0.yaml) and canary
# deployments (ex: fence-canary)
#
# @param depName deployment name or alias
# @param depVersion deployment version - extracted from manifest if not set - ignores "null" value
# @return echo path to yaml, non-zero exit code if path does not exist
#
gen3_roll_path() {
  local depName
  local deployVersion

  depName="$1"
  shift
  if [[ -z "$depName" ]]; then
    gen3_log_err "gen3_roll_path" "roll deployment name not specified"
    return 1
  fi
  if [[ -f "$depName" ]]; then # path to yaml given
    echo "$depName"
    return 0
  fi
  if [[ $# -gt 0 ]]; then
    deployVersion="${1}"
    shift
  else
    local manifestPath
    manifestPath="$(g3k_manifest_path)"
    deployVersion="$(jq -r ".[\"$depName\"][\"deployment_version\"]" < "$manifestPath")"
  fi
  local cleanName
  local serviceName
  local templatePath
  cleanName="${depName%[-_]deploy*}"
  serviceName="${cleanName/-canary/}"
  # roll the correct root frontend service
  frontend_root="$(g3k_config_lookup ".global.frontend_root" "$manifestPath")"
  if [[ ($serviceName == "frontend-framework" && $frontend_root == "gen3ff") || ($serviceName == "portal" && $frontend_root != "gen3ff") ]]; then
    cleanName="$cleanName-root"
  fi

  templatePath="${GEN3_HOME}/kube/services/${serviceName}/${cleanName}-deploy.yaml"
  if [[ -n "$deployVersion" && "$deployVersion" != null ]]; then
    templatePath="${GEN3_HOME}/kube/services/${serviceName}/${cleanName}-deploy-${deployVersion}.yaml"
  fi
  echo "$templatePath"
  if [[ -f "$templatePath" ]]; then
    return 0
  else
    gen3_log_err "gen3_roll_path" "roll path does not exist: $templatePath"
    return 1
  fi
}



if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  # Support sourcing this file for test suite
  command="$1"
  shift
  case "$command" in
    "filter")
      yaml="$1"
      manifest=""
      shift
      if [[ "$1" =~ \.json$ ]]; then
        manifest="$1"
        shift
      fi
      g3k_manifest_filter "$yaml" "$manifest" "$@"
      ;;
    "configmaps")
      gen3_gitops_configmaps "$@"
      ;;
    "configmaps-from-json")
      gen3_gitops_json_to_configmap "$@"
      ;;
    "configmaps-list")
      gen3_gitops_configmaps_list "$@"
      ;;
    "enforce")
      gen3_gitops_enforcer "$@"
      ;;
    "etl-convert")
      gen3_gitops_etlconvert "$@"
      ;;
    "folder")
      dirname "$(g3k_manifest_path)"
      ;;
    "history")
      gen3_gitops_history "$@"
      ;;
    "manifest")
      g3k_manifest_path
      ;;
    "rsync")
      gen3_gitops_rsync "$@"
      ;;
    "repolist")
      gen3_gitops_repolist "$@"
      ;;
    "rollpath")
      gen3_roll_path "$@"
      ;;
    "sshlist")
      gen3_gitops_sshlist "$@"
      ;;
    "sync")
      gen3_gitops_sync "$@"
      ;;
    "taglist")
      gen3_gitops_repo_taglist "$@"
      ;;
    "dotag")
      gen3_gitops_repo_dotag "$@"
      ;;
    "tfplan")
      gen3_run_tfplan "$@"
      ;;
    "tfapply")
      gen3_run_tfapply "$@"
      ;;
    *)
      help
      ;;
  esac
fi
