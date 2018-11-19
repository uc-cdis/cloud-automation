#
# Unified entrypoint for gitops and manifest related commands
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

help() {
  gen3 help gitops
}

#
# command to update dictionary URL and image versions
#
gen3_gitops_sync() {
  g3k_manifest_init
  local dict_roll=false
  local versions_roll=false

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

  # image versions check
  if g3kubectl get configmap manifest-versions; then
    oldJson=$(g3kubectl get configmap manifest-versions -o=json | jq ".data")
  fi
  newJson=$(g3k_config_lookup ".versions")
  echo "old JSON is: $oldJson"
  echo "new JSON is: $newJson"
  if [[ -z $newJson ]]; then
    echo "Manifest does not have versions section. Unable to get new versions, skipping version update."
  elif [[ -z $oldJson ]]; then
    echo "Configmap manifest-versions does not exist, cannot extract old versions. Using new versions."
    versions_roll=true
  else 
    changeFlag=0
    for key in $(echo $newJson | jq -r "keys[]"); do
      newVersion=$(echo $newJson | jq ".\"$key\"")
      oldVersion=$(echo $oldJson | jq ".\"$key\"") 
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
  
  echo "DRYRUN flag is: $GEN3_DRY_RUN"
  if [ "$GEN3_DRY_RUN" = true ]; then
    echo "DRYRUN flag detected, not rolling"
  else
    if [ "$dict_roll" = true -o "$versions_roll" = true ]; then
      echo "changes detected, rolling"
      gen3 kube-roll-all
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
# g3k command to create configmaps from manifest
#
gen3_gitops_configmaps() {
  local manifestPath
  manifestPath=$(g3k_manifest_path)
  if [[ ! -f "$manifestPath" ]]; then
    echo -e "$(red_color "ERROR: manifest does not exist - $manifestPath")" 1>&2
    return 1
  fi

  if ! grep -q global $manifestPath; then
    echo -e "$(red_color "ERROR: manifest does not have global section - $manifestPath")" 1>&2
    return 1
  fi

  # if old configmaps are found, deletes them
  if g3kubectl get configmaps -l app=manifest | grep -q NAME; then
    g3kubectl delete configmaps -l app=manifest
  fi

  g3kubectl create configmap manifest-all --from-literal json="$(g3k_config_lookup "." "$manifestPath")"
  g3kubectl label configmap manifest-all app=manifest

  local key
  local key2
  local value
  local execString

  for key in $(g3k_config_lookup 'keys[]' "$manifestPath"); do
    if [[ $key != 'notes' ]]; then
      local cMapName="manifest-$key"
      execString="g3kubectl create configmap $cMapName "
      for key2 in $(g3k_config_lookup ".[\"$key\"] | keys[]" "$manifestPath" | grep '^[a-zA-Z]'); do
        value="$(g3k_config_lookup ".[\"$key\"][\"$key2\"]" "$manifestPath")"
        if [[ -n "$value" ]]; then
          execString+="--from-literal $key2='$value' "
        fi
      done
      local jsonSection="--from-literal json='$(g3k_config_lookup ".[\"$key\"]" "$manifestPath")'"
      execString+=$jsonSection
      eval $execString
      g3kubectl label configmap $cMapName app=manifest
    fi
  done
}

declare -a gen3_gitops_repolist_arr=(
  uc-cdis/arborist
  uc-cdis/fence
  uc-cdis/peregrine
  uc-cdis/gen3-arranger
  uc-cdis/gen3-spark
  uc-cdis/indexd
  uc-cdis/docker-nginx
  uc-cdis/pidgin
  uc-cdis/data-portal
  uc-cdis/sheepdog
  uc-cdis/tube
  #frickjack/misc-stuff  # just for testing
)

declare -a gen3_gitops_sshlist_arr=(
dcfprod@dcfprod.csoc
staging@dcfprod.csoc
dcfqav1@dcfqa.csoc
bhcprodv2@braincommons.csoc
bloodv2@occ.csoc
dataguids@gtex.csoc
gtexdev@gtex.csoc
gtexprod@gtex.csoc
niaidprod@niaiddh.csoc
prodv1@kf.csoc
edcprodv2@occ-edc.csoc
ibdgc@ibdgc.csoc
ncigdcprod@ncigdc.csoc
vadcprod@vadc.csoc
accountprod@account.csoc
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
      gen3_gitops_configmaps
      ;;
    "rsync")
      gen3_gitops_rsync "$@"
      ;;
    "repolist")
      gen3_gitops_repolist "$@"
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
    *)
      help
      ;;
  esac
fi
