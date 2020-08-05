source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


# lib --------------------------

GEN3_TEMPLATE_FOLDER="${GEN3_HOME}/gen3/lib/bootstrap/templates"
OLD_VPC_NAME="${vpc_name:-""}"
# we don't want to screw around with legacy vpc_name code
unset vpc_name

# 
# Extend the prepuller yaml with data from the manifest
#
# @param varargs img1 img2 ... - additional images as args - mostly to support testing
#
gen3_bootstrap_template() {  
  local hostname=""
  hostname="$(gen3 api hostname)"
  local environment="${vpc_name:-""}"
  local temp
  if temp="$(gen3 api environment)"; then
    environment="${temp}"
  fi
  local result="$(cat - <<EOM
{
    "hostname": "${hostname}",
    "environment": "${environment}"
}
EOM
  )"

  #
  # Let's not put any secrets in the template ...
  #
  #local it
  #for it in $(gen3 db server list); do
  #  #gen3_log_info "adding $it to $result"
  #  result="$(jq -r --argjson it "$(gen3 db server info $it)" '.databases=(.databases + [$it])' <<< "$result")"
  #done
  #gen3_log_info "databases[] entries have form { db_host, db_username, db_password, db_database }"
  jq -r '.' <<<"$result"
}


#
# Let helper to find the manifest folder.
# echo the manifest folder
#
gen3_bootstrap_manfolder() {
  local config
  config="$1"
  shift
  local hostname
  if ! hostname="$(jq -r .hostname <<<"$config")" || [[ -z "$hostname" ]]; then
    gen3_log_err "invalid hostname - $hostname - from config: $config"
    return 1
  fi
  local manifestFolder="$GEN3_SECRETS_ROOT/cdis-manifest/$hostname"
  echo "$manifestFolder"
}


#
# Verify that we won't write over
# existing configuration, and prompt the
# user before proceeding
#
gen3_bootstrap_prep() {
  local config
  config="$1"
  shift
  local manifestFolder
  manifestFolder="$(gen3_bootstrap_manfolder "$config")" || return 1
  if [[ ! -d "$manifestFolder" ]]; then
    gen3_log_info "initializing manifest folder: rsync -av $GEN3_TEMPLATE_FOLDER/cdis-manifest/ $manifestFolder/"
    mkdir -p "$manifestFolder"
    rsync -av "$GEN3_TEMPLATE_FOLDER/cdis-manifest/" "$manifestFolder/"
  fi
  local secretsFolder="$(gen3_secrets_folder)"
  if [[ ! -d "$secretsFolder" ]]; then
    gen3_log_info "initializing secrets folder: rsync -av $GEN3_TEMPLATE_FOLDER/Gen3Secrets/ $secretsFolder/"
    mkdir -p "$manifestFolder"
    rsync -av "$GEN3_TEMPLATE_FOLDER/Gen3Secrets/" "$secretsFolder/"
  fi
}

#
# Copy the maintenance page into place.
# Assumes the global configmap has been loaded into k8s
#
gen3_bootstrap_dashboard() {
  local config
  config="$1"
  shift
  local manifestFolder
  manifestFolder="$(gen3_bootstrap_manfolder "$config")" || return 1
  local folder="$manifestFolder/dashboard/Public/maintenance-page"
  
  if [[ -e "$folder" ]]; then
    gen3_log_info "dashboard app already exists $folder"
    return 0
  fi
  gen3_log_info "rsync -av $GEN3_HOME/files/dashboard/maintenance-page/ $folder/maintenance-page/"
  mkdir -p "$folder"
  rsync -av "$GEN3_HOME/files/dashboard/maintenance-page/" "$folder/maintenance-page/"
}

gen3_bootstrap_sower() {
  local config
  config="$1"
  shift
  local manifestFolder
  manifestFolder="$(gen3_bootstrap_manfolder "$config")" || return 1
  
  local configFile="$manifestFolder/manifests/sower/sower.json"
  
  if [[ -e "$configFile" ]]; then
    gen3_log_info "sower.json already exists $configFile"
    return 0
  fi
  local templatePath="$GEN3_TEMPLATE_FOLDER/cdis-manifest/manifests/sower/sower.json"
  gen3_log_info "installing $configFile"
  mkdir -p "$(dirname "$configFile")"
  cp "$templatePath" "$configFile"
}

gen3_bootstrap_manifest() {
  local config
  config="$1"
  shift
  local manifestFolder
  manifestFolder="$(gen3_bootstrap_manfolder "$config")" || return 1
  
  local configFile="$manifestFolder/manifest.json"
  
  if [[ -e "$configFile" ]]; then
    gen3_log_info "manifest.json already exists $configFile"
    return 0
  fi
  local templatePath="$GEN3_TEMPLATE_FOLDER/cdis-manifest/manifest.json"
  gen3_log_info "installing $configFile"
  mkdir -p "$(dirname "$configFile")"
  cp "$templatePath" "$configFile"
}

gen3_bootstrap_00configmap() {
  local confFile="$(gen3_secrets_folder)/00configmap.yaml"
  
  if g3kubectl get configmap global > /dev/null 2>&1; then
    gen3_log_info "global configmap already exists - skipping $confFile"
    return 0
  fi
  if [[ -f "$confFile" ]]; then
    gen3_log_info "$confFile already exists"
    return 0
  fi
  gen3_log_info "generating $confFile"
  local templatePath="$GEN3_TEMPLATE_FOLDER/Gen3Secrets/00configmap.yaml"
  local template
  if ! cp "$templatePath" "$confFile"; then
    gen3_log_err "Failed to copy template into path: $templatePath"
    return 1
  fi
  local hostname="$(jq -r .hostname <<<"${confFile}")"
  local environment="$(jq -r .environment <<< "${confFile}")"
  sed -i "s/hostname:.*/hostname: $hostname/g" "$confFile"
  sed -i "s/environment:.*/environment: $environment/g" "$confFile"

  gen3_log_info "verify the contents of $confFile"
  gen3_log_info "then: g3kubectl apply -f $confFile"
}

gen3_bootstrap_dbfarm() {
  local confFile="$(gen3_secrets_folder)/g3auto/dbfarm/servers.json"
  if [[ -f "$confFile" ]]; then
    gen3_log_info "dbfarm config file already exists: $confFile"
    return 0
  fi
  local credsFile="$(gen3_secrets_folder)/g3auto/dbfarm/servers.json"
  if [[ -f "$credsFile" ]]; then
    gen3_log_info "dbfarm config file does not exist, but creds.json does - $credsFile"
    gen3_log_info "run this command to bootstrap the dbfarm from creds.json: gen3 db server list"
    return 1
  fi

  gen3_log_info "copying dbfarm template into place at $confFile"
  
  gen3_log_info "populate servers.json with credentials for at least one database server"
  gen3_log_info "then run: gen3 secrets sync 'setup dbfarm' && gen3 db server list"
  mkdir -p "$(dirname "$confFile")"
  cp "$GEN3_TEMPLATE_FOLDER/Gen3Secrets/g3auto/dbfarm/servers.json" "$confFile"
}

gen3_bootstrap_credsjson() {
  local confFile="$(gen3_secrets_folder)/creds.json"
  if [[ -f "$confFile" ]]; then
    gen3_log_info "creds config file already exists: $confFile"
    return 0
  fi

  gen3_log_info "copying creds.json template into place at $confFile"
  gen3_log_info "creds.json automation not complete - do the following"
  gen3_log_info "gen3 db setup indexing && gen3 db setup security && gen3 db setup graphdb"
  gen3_log_info "then populate creds.json with creds for the newly created databases"
  gen3_log_info "for indexd, fence, and sheepdog respectively"
  cp "$GEN3_TEMPLATE_FOLDER/Gen3Secrets/creds.json" "$confFile"
  return 1
}

#
# fence_config private and public configs
#
gen3_bootstrap_fenceconfig() {
  local confFile="$(gen3_secrets_folder)/apis_configs/fence-config.yaml"

  if [[ -e "$confFile" ]]; then
    gen3_log_info "fence-config already exists: $confFile"
    return 0
  fi
  local manifestFolder
  manifestFolder="$(gen3_bootstrap_manfolder "$config")" || return 1
  local pubConfFile="$manifestFolder/manifests/fence/fence-config-public.yaml"
  gen3_log_info "Copying private fence-config template into place at $confFile"
  mkdir -p "$(dirname "$confFile")"
  cp "$GEN3_TEMPLATE_FOLDER/Gen3Secrets/apis_configs/fence-config.yaml" "$confFile"
  if [[ -e "$pubConfFile" ]]; then
    gen3_log_err "fence-config-public already exists - $pubConfFile"
    gen3_log_err "verify fence-config-public is consistent with the private config at $confFile"
    return 1
  fi  
  mkdir -p "$(dirname "$pubConfFile")"
  cp "$GEN3_TEMPLATE_FOLDER/cdis-manifest/manifests/fence/fence-config-public.yaml" "$pubConfFile"
  return 1
}


gen3_bootstrap_go() {
  if [[ -n "$JENKINS_HOME" ]]; then
    gen3_log_err "Do not do this in CICD!"
    exit 1
  fi

  if [[ $# -lt 1 ]]; then
    gen3_log_err "Use: bootstrap go config.json"
    return 1
  fi
  local configFile="$1"
  shift
  local config
  config="$(jq -r . <"$configFile")" || return 1
  gen3_bootstrap_prep "$config" 
  echo "" 1>&2
  gen3_bootstrap_00configmap "$config"
  echo "" 1>&2
  gen3_bootstrap_dbfarm "$config"
  echo "" 1>&2
  gen3_bootstrap_credsjson "$config"
  echo "" 1>&2
  gen3_bootstrap_fenceconfig "$config"
  echo "" 1>&2
  gen3_bootstrap_manifest "$config"
  echo "" 1>&2
  gen3_bootstrap_sower "$config"
  echo "" 1>&2
  gen3_bootstrap_dashboard "$config"
}

# main -----------------------------

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  # Support sourcing this file for test suite
  command="$1"
  shift
  case "$command" in
    "template")
      gen3_bootstrap_template "$@"
      ;;
    "go")
      gen3_bootstrap_go "$@"
      ;;
    *)
      gen3 help bootstrap
      ;;
  esac

  exit $?
fi
