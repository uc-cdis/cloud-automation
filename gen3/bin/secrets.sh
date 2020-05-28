#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"
gen3_load "gen3/lib/secrets/rotate-gcp"
gen3_load "gen3/lib/secrets/rotate-postgres"

# lib --------------------------------------

#
# Initialize the secrets folder as a git repository
# if necessary
#
# @return 0 if the secrets folder is configured for git commits
gen3_secrets_init_git() {
  if [[ -d "$(gen3_secrets_folder)" && -z "${JENKINS_HOME}" ]]; then
    (
      # issue git commands in the secrets folder
      cd "$(gen3_secrets_folder)"
    
      # initialize secrets folder as a git repo
      if [[ ! -d "$(gen3_secrets_folder)/.git" ]]; then
        gen3_log_info "Initializing $(gen3_secrets_folder) directory as git repo"
        git init
      fi
      if [[ -z "$(git config user.name)" ]]; then
        git config user.name "gen3"
      fi
      if [[ -z "$(git config user.email)" ]]; then
        git config user.email "admin@gen3.org"
      fi
      if [[ -z "$(git config core.editor)" ]]; then
        git config core.editor vi
      fi
      #
      # ensure a backup exists
      # see here for info about local backup config
      #   https://matthew-brett.github.io/curious-git/curious_remotes.html
      local backup="$(dirname "$(gen3_secrets_folder)")/backup"
      if [[ ! -d "$backup" ]]; then
        gen3_log_info "Initializing backup for $(gen3_secrets_folder)"
        git init --bare "$backup/secrets.git"
        git remote add secrets_backup "$backup/secrets.git"
      fi

      if [[ ! -f "$(gen3_secrets_folder)/.gitignore" ]] || grep '\.env' "$(gen3_secrets_folder)/.gitignore" > /dev/null 2>&1; then
        cat - > "$(gen3_secrets_folder)/.gitignore" <<EOM
*.bak
*.old
*~
*.swp
.DS_Store
EOM
      fi
    )
    return 0
  fi
  return 1
}

#
# Commit and push any outstanding changes to the secrets git repo
#
# @param message for git commit - otherwise uses default
# @return 0 if local git repo exists, false if in Jenkins or container or whatever
#
gen3_secrets_commit() {
  local message
  message="gen3_secrets_commit"
  if [[ $# > 0 ]]; then
    message="$1"
    shift
  fi
  if gen3_secrets_init_git; then
    (
      # do git work in the secrets folder
      cd "$(gen3_secrets_folder)"

      # remove legacy services link
      if [[ -L services ]]; then
        rm services
      fi

      # assert there are no unstaged or uncommitted files
      if [[ ! -z "$(git status --porcelain)" ]]; then
        gen3_log_info "gen3_secrets_commit" "commiting changes to $(gen3_secrets_folder)"
        git add .
        git commit -n -m "$message"
      fi

      gen3_log_info "gen3_secrets_commit" "attempting to update secrets backup"
      git push -f -u secrets_backup master || true
    )
    return 0
  fi
  return 1
}

#
# Create secrets associated with creds.json and g3auto/.
# Calls gen3_secrets_commit as side effect
#
# @param message for git commit - otherwise uses default
# @return 0 if local git repo exists, false if in Jenkins or container or whatever
#
gen3_secrets_sync() {
  if gen3_secrets_commit "$@"; then
    #
    # Handle creds.json secrets first
    #
    local credsFile
    credsFile="$(gen3_secrets_folder)/creds.json"
    if [[ ! -f "$credsFile" ]]; then
      gen3_log_err "gen3_secrets_sync_creds" "creds.json file not found at $credsFile"
      return 1
    fi

    local keys
    # exclude deprecated or specially handled secrets
    keys="$(jq -r '((.|keys)-["gdcapi", "userapi", "ssjdispatcher"])|join("\n")' < "$credsFile")"
    local serviceName
    local secretName
    local secretValueFile
    #
    # delete all the secrets first, then sleep a second
    # to avoid race condition
    #
    for serviceName in $keys; do
      secretName="${serviceName}-creds"
      g3kubectl delete secret "$secretName" > /dev/null 2>&1
    done
    sleep 1  # I think delete is async - give backend a second to finish
    for serviceName in $keys; do
      secretName="${serviceName}-creds"
      secretValueFile="$(mktemp "$XDG_RUNTIME_DIR/creds.json_XXXXX")"
      jq -r ".[\"$serviceName\"]" > "$secretValueFile" < "$credsFile"
      g3kubectl create secret generic "$secretName" "--from-file=creds.json=${secretValueFile}"
      rm "$secretValueFile"
    done
  
    #---------------------------
    # now try to process the g3auto/ folder
    #
    if [[ -d "$(gen3_secrets_folder)/g3auto" ]]; then
      (
        cd "$(gen3_secrets_folder)/g3auto"
        # delete first, then sleep to avoid race condition re-creating
        for serviceName in *; do
          if [[ -d "$serviceName" ]]; then
            (
              cd "$serviceName"
              secretName="${serviceName}-g3auto"
              g3kubectl delete secret "$secretName" > /dev/null 2>&1
            )
          fi
        done
        sleep 1  # avoid race
        for serviceName in *; do
          if [[ -d "$serviceName" ]]; then
            (
              cd "$serviceName"
              secretName="${serviceName}-g3auto"
              # in subshell now - forget about local
              flags=""
              for secretValueFile in *; do
                if [[ -f "$secretValueFile" && "$secretValueFile" =~ ^[a-zA-Z0-9][^\ ]*[a-zA-Z0-9]$ && ! "$secretValueFile" =~ \.swp$ ]]; then
                  flags="$flags --from-file=$secretValueFile"
                else
                  gen3_log_info "gen3_secrets_sync" "ignoring funny secrets file g3auto/$serviceName/$secretValueFile"
                fi
              done
              if [[ -n "$flags" ]]; then
                g3kubectl create secret generic "$secretName" $flags
              fi
            )
          fi
        done
      )
    fi

    #-------
    # update fence-config too - why not?
    if [[ -f "$(gen3_secrets_folder)/apis_configs/fence-config.yaml" ]]; then
      g3kubectl delete secret "fence-config" > /dev/null 2>&1
      g3kubectl create secret generic fence-config "--from-file=fence-config.yaml=$(gen3_secrets_folder)/apis_configs/fence-config.yaml"
    fi

    return 0
  fi
  return 1
}

#
# Shortcut for the base64 decode dance
#
gen3_secrets_decode() {
  local secretName
  local keyName
  local result
  local tempFile

  keyName=""
  result=0
  if [[ $# -lt 1 ]]; then
    gen3_log_err gen3_secrets_decode "no secret name given"
    return 1
  fi
  secretName="$1"
  shift
  tempFile="$(mktemp "$XDG_RUNTIME_DIR/secret.json_XXXXX")"
  if ! g3kubectl get secrets "$secretName" -ojson > "$tempFile"; then
    gen3_log_err "gen3_secrets_decode" "no secret $secretName"
    rm $tempFile
    return 1
  fi

  if [[ $# -gt 0 ]]; then
    keyName="$1"
    shift
    if jq -e -r ".data[\"$keyName\"]" < "$tempFile" > /dev/null 2>&1; then
      jq -e -r ".data[\"$keyName\"]" < "$tempFile" | base64 --decode
    else
      gen3_log_err "gen3_secrets_decode" "$secretName has no key $keyName"
      result=1
    fi
  else
    local keyList
    keyList="$(jq -e -r '.data|keys|join("\n")' < "$tempFile")"
    for keyName in $keyList; do
      echo "-------- ${keyName}:"
      jq -e -r ".data[\"$keyName\"]" < "$tempFile" | base64 --decode
      echo "--------"
    done
  fi
  rm "$tempFile"
  return $result
}

gen3_secrets_rotate() {
  if [[ $# -lt 1 ]]; then
    gen3_log_err "use: rotate postgres|whatever - see gen3 secrets help"
    return 1
  fi
  local command="$1"
  shift
  case "$command" in
    "postgres")
      gen3_secrets_rotate_postgres "$@"
      ;;
    "newdb")
      if [[ $# -lt 2 ]]; then
        gen3_log_err "2 arguments required: gen3 secrets rotate newdb $serviceName $dbName"
        return 1
      fi
      gen3_secrets_rotate_pguser "$@"
      ;;
    *)
      gen3_log_err "unknown rotate command: $command"
      return 1
      ;;
  esac
}

gen3_secrets_revoke() {
  if [[ $# -lt 1 ]]; then
    gen3_log_err "use: revoke postgres|whatever - see gen3 secrets help"
    return 1
  fi
  local command="$1"
  shift
  case "$command" in
    "postgres")
      gen3_secrets_revoke_postgres "$@"
      ;;
    *)
      gen3_log_err "unknown rotate command: $command"
      return 1
      ;;
  esac
}

# main -----------------------------

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  command="$1"
  shift
  case "$command" in
    "commit")
      gen3_secrets_commit "$@"
      ;;
    "gcp")
      gen3_secrets_gcp "$@"
      ;;
    "sync")
      gen3_secrets_sync "$@"
      ;;
    "decode")
      gen3_secrets_decode "$@"
      ;;
    "rotate")
      gen3_secrets_rotate "$@"
      ;;
    "revoke")
      gen3_secrets_revoke "$@"
      ;;
    *)
      gen3 help secrets
      ;;
  esac
fi
