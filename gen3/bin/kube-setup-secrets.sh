#!/bin/bash
#
# Initializes the Gen3 k8s secrets and services.
#
set -e

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"
gen3_load "gen3/lib/g3k_manifest"

mkdir -p "${WORKSPACE}/${vpc_name}/apis_configs"

if [[ -f "${WORKSPACE}/${vpc_name}/creds.json" ]]; then # update secrets
  #
  # Setup the files that will become secrets in "${WORKSPACE}/$vpc_name/apis_configs"
  #
  cd "${WORKSPACE}"/${vpc_name}

  # Note: look into 'kubectl replace' if you need to replace a secret
  if ! g3kubectl get secrets/indexd-secret > /dev/null 2>&1; then
    g3kubectl create secret generic indexd-secret --from-file=local_settings.py="${GEN3_HOME}/apis_configs/indexd_settings.py" "--from-file=${GEN3_HOME}/apis_configs/config_helper.py"
  fi
  if ! g3kubectl get secret indexd-creds > /dev/null 2>&1; then
    credsFile=$(mktemp -p "$XDG_RUNTIME_DIR" "creds.json_XXXXXX")
    jq -r .indexd < creds.json > "$credsFile"
    g3kubectl create secret generic indexd-creds "--from-file=creds.json=${credsFile}"
  fi

  cd "${WORKSPACE}"/${vpc_name}
fi

if [[ -f "${WORKSPACE}/${vpc_name}/creds.json" ]]; then # update secrets
  if ! g3kubectl get secrets/aws-es-proxy > /dev/null 2>&1; then
    credsFile=$(mktemp -p "$XDG_RUNTIME_DIR" "creds.json_XXXXXX")
    creds=$(jq -r ".es|tostring" < creds.json |sed -e 's/[{-}]//g' -e 's/"//g' -e 's/:/=/g')
    if [[ "$creds" != null ]]; then
      echo "[default]" > "$credsFile"
      IFS=',' read -ra CREDS <<< "$creds"
      for i in "${CREDS[@]}"; do
        echo ${i} >> "$credsFile"
      done
      g3kubectl create secret generic aws-es-proxy "--from-file=credentials=${credsFile}"
    else
      echo "WARNING: creds.json does not include AWS elastic search credentials - not initializing aws-es-proxy secret"
    fi
  fi
fi

if ! g3kubectl get configmaps global > /dev/null 2>&1; then
  if [[ -f "${WORKSPACE}/${vpc_name}/00configmap.yaml" ]]; then
    g3kubectl apply -f "${WORKSPACE}/${vpc_name}/00configmap.yaml"
  else
    echo "ERROR: unable to configure global configmap - missing ${WORKSPACE}/${vpc_name}/00configmap.yaml"
    exit 1
  fi
fi
if ! g3kubectl get configmap config-helper > /dev/null 2>&1; then
  gen3 update_config config-helper "${GEN3_HOME}/apis_configs/config_helper.py"
fi

let configmapsExpireTime="$(date +%s) - 120"
configmapsFlagFile="${WORKSPACE}/${vpc_name}/.configmapsFlagFile"
# Avoid creating configmaps more than once every two minutes
# (gen3 roll all calls this over and over)
if [[ (! -f "$configmapsFlagFile") || $(stat -c %Y "$configmapsFlagFile") -lt "$configmapsExpireTime" ]]; then
  echo "creating manifest configmaps"
  gen3 gitops configmaps
  touch "$configmapsFlagFile"
fi


if [[ -f "${WORKSPACE}/${vpc_name}/creds.json" ]]; then # update fence secrets
  if [ ! -d "${WORKSPACE}/${vpc_name}" ]; then
    echo "${WORKSPACE}/${vpc_name} does not exist"
    exit 1
  fi

  cd "${WORKSPACE}/${vpc_name}"

  if ! g3kubectl get secret fence-creds > /dev/null 2>&1; then
    credsFile=$(mktemp -p "$XDG_RUNTIME_DIR" "creds.json_XXXXXX")
    jq -r .fence < creds.json > "$credsFile"
    g3kubectl create secret generic fence-creds "--from-file=creds.json=${credsFile}"
  fi

  cd "${WORKSPACE}/${vpc_name}"
  # Generate RSA private and public keys.
  # TODO: generalize to list of key names?
  mkdir -p jwt-keys
  mkdir -p ssh-keys

  # Create keypairs for fence. Following the requirements from fence, the
  # keypairs go in subdirectories of the base keys directory, where the
  # subdirectories are named as an ISO 8601 timestamp of when the keypair is
  # created.

  # If there are keypair subdirectories already, don't make a new one by
  # default. (`mindepth -2` will restrict to searching for subdirectories.)
  existingKeys="$(find jwt-keys -mindepth 2 -name 'jwt_public_key.pem' -print 2>/dev/null)"
  if test -z "$existingKeys"; then
    # For backwards-compatibility: move old keys into keys subdirectory so that
    # fence can load them. Assume that old keypairs had key ID "key-01".
    newDirForOldKeys="jwt-keys/key-01"
    mkdir -p "$newDirForOldKeys"
    if [[ -f jwt-keys/jwt_public_key.pem && -f jwt-keys/jwt_private_key.pem ]]; then
      mv jwt-keys/*.pem "$newDirForOldKeys/"
    fi
    if [[ ! -f ${newDirForOldKeys}/jwt_public_key.pem || ! -f ${newDirForOldKeys}/jwt_private_key.pem ]]; then
      openssl genrsa -out ${newDirForOldKeys}/jwt_private_key.pem 2048
      openssl rsa -in ${newDirForOldKeys}/jwt_private_key.pem -pubout -out ${newDirForOldKeys}/jwt_public_key.pem
    fi

    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    mkdir jwt-keys/${timestamp}
    openssl genrsa -out jwt-keys/${timestamp}/jwt_private_key.pem 2048
    openssl rsa -in jwt-keys/${timestamp}/jwt_private_key.pem -pubout -out jwt-keys/${timestamp}/jwt_public_key.pem
  fi

  # sftp key
  if [ ! -f ssh-keys/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -C "dev@test.com" -N "" -f ssh-keys/id_rsa
  fi

  if ! g3kubectl get configmaps/fence > /dev/null 2>&1; then
    #
    # Only restore local user.yaml if the fence configmap does not exist.
    # Most commons sync the user db from an S3 bucket.
    #
    if [[ ! -f "${WORKSPACE}"/${vpc_name}/apis_configs/user.yaml ]]; then
      # user database for accessing the commons ...
      cp "${GEN3_HOME}/apis_configs/user.yaml" "${WORKSPACE}"/${vpc_name}/apis_configs/
    fi
    g3kubectl create configmap fence --from-file=apis_configs/user.yaml
  fi

  if ! g3kubectl get configmaps/logo-config > /dev/null 2>&1; then
    #
    # Only restore logo if the configmap does not exist.
    #
    logoPath="$(dirname $(g3k_manifest_path))/fence/logo.svg"
    if [[ ! -f "${logoPath}" ]]; then
      # fallback to legacy path
      logoPath="${WORKSPACE}/${vpc_name}/apis_configs/logo.svg"
    fi
    if [[ ! -f "${logoPath}" ]]; then
      # fallback to default gen3 logo
      logoPath="${GEN3_HOME}/apis_configs/logo.svg"
    fi
    g3kubectl create configmap logo-config --from-file="${logoPath}"
  fi

  if ! g3kubectl get secrets/fence-config > /dev/null 2>&1; then
    # load updated fence-config.yaml into secret if it exists
    fence_config=${WORKSPACE}/${vpc_name}/apis_configs/fence-config.yaml
    if [[ -f ${fence_config} ]]; then
      echo "loading fence config from file..."
      if g3kubectl get secrets/fence-config > /dev/null 2>&1; then
        g3kubectl delete secret fence-config
      fi
      g3kubectl create secret generic fence-config "--from-file=fence-config.yaml=${fence_config}"
    else
      echo "running job to create fence-config.yaml."
      echo "job will inject creds.json into fence-config.yaml..."
      echo "NOTE: Some default config values from fence-config.yaml will be replaced"
      echo "      Run \"gen3 joblogs config-fence\" for details"
      gen3 runjob config-fence

      # dump fence-config secret into file so user can edit.
      let count=1
      while ((count < 50)); do
        if g3kubectl get secrets/fence-config > /dev/null 2>&1; then
          break
        fi
        echo "waiting for fence-config secret from job..."
        sleep 2
        let count=${count}+1
      done
      if g3kubectl get secrets/fence-config > /dev/null 2>&1; then
        echo "found fence-config!"
        echo "dumping fence configuration into file from fence-config secret..."
        g3kubectl get secrets/fence-config -o json | jq -r '.data["fence-config.yaml"]' | base64 --decode > "${fence_config}"
      else
        echo "ERROR: could not find fence-config within the timeout!"
      fi
    fi
  fi

  if ! g3kubectl get secrets/fence-google-app-creds-secret > /dev/null 2>&1; then
    if [[ ! -f "./apis_configs/fence_google_app_creds_secret.json" ]]; then
      touch "./apis_configs/fence_google_app_creds_secret.json"
    fi
    echo "create fence-google-app-creds-secret using current creds file apis_configs/fence_google_app_creds_secret.json"
    g3kubectl create secret generic fence-google-app-creds-secret --from-file=fence_google_app_creds_secret.json=./apis_configs/fence_google_app_creds_secret.json
  fi

  if ! g3kubectl get secrets/fence-google-storage-creds-secret > /dev/null 2>&1; then
    if [[ ! -f "./apis_configs/fence_google_storage_creds_secret.json" ]]; then
      touch "./apis_configs/fence_google_storage_creds_secret.json"
    fi
    echo "create fence-google-storage-creds-secret using current creds file apis_configs/fence_google_storage_creds_secret.json"
    g3kubectl create secret generic fence-google-storage-creds-secret --from-file=fence_google_storage_creds_secret.json=./apis_configs/fence_google_storage_creds_secret.json
  fi

  if ! g3kubectl get configmaps/projects > /dev/null 2>&1; then
    if [[ ! -f "./apis_configs/projects.yaml" ]]; then
      touch "apis_configs/projects.yaml"
    fi
    g3kubectl create configmap projects --from-file=apis_configs/projects.yaml
  fi

  if ! g3kubectl get secrets/fence-jwt-keys > /dev/null 2>&1; then
    rm -rf $XDG_RUNTIME_DIR/jwt-keys.tar
    tar cvJf $XDG_RUNTIME_DIR/jwt-keys.tar jwt-keys
    g3kubectl create secret generic fence-jwt-keys --from-file=$XDG_RUNTIME_DIR/jwt-keys.tar
  fi

  if ! g3kubectl get secrets/fence-ssh-keys > /dev/null 2>&1; then
    g3kubectl create secret generic fence-ssh-keys --from-file=id_rsa=./ssh-keys/id_rsa --from-file=id_rsa.pub=./ssh-keys/id_rsa.pub
  fi

  if ! g3kubectl get configmaps/fence-sshconfig > /dev/null 2>&1; then
    mkdir -p ./apis_configs/.ssh
    if [[ ! -f "./apis_configs/.ssh/config" ]]; then
        echo '''
        Host squid.internal
          ServerAliveInterval 120
          HostName cloud-proxy.internal.io
          User ubuntu
          ForwardAgent yes

        Host sftp.planx
          ServerAliveInterval 120
          HostName sftp.planx-pla.net
          User foo
          ForwardAgent yes
          IdentityFile ~/.ssh/id_rsa
          ProxyCommand ssh ubuntu@squid.internal nc %h %p 2> /dev/null

       Host sftp.dbgap
          ServerAliveInterval 120
          HostName ftp-private.ncbi.nlm.nih.gov
          User BDC-TP
          ForwardAgent yes
          IdentityFile ~/.ssh/id_rsa
          ProxyCommand ssh ubuntu@squid.internal nc %h %p 2> /dev/null

        Host cloud-proxy.internal.io
          StrictHostKeyChecking no
          UserKnownHostsFile=/dev/null
        ''' > ./apis_configs/.ssh/config
    fi
    g3kubectl create configmap fence-sshconfig --from-file=./apis_configs/.ssh/config
  fi
fi

if [[ -f "${WORKSPACE}/${vpc_name}/creds.json" ]]; then # update peregrine secrets
  if [ ! -d "${WORKSPACE}/${vpc_name}" ]; then
    echo "${WORKSPACE}/${vpc_name} does not exist"
    exit 1
  fi

  cd "${WORKSPACE}/${vpc_name}"

  if ! g3kubectl get secret peregrine-creds > /dev/null 2>&1; then
    credsFile=$(mktemp -p "$XDG_RUNTIME_DIR" "creds.json_XXXXXX")
    jq -r .peregrine < creds.json > "$credsFile"
    g3kubectl create secret generic peregrine-creds "--from-file=creds.json=${credsFile}"
  fi

  cd "${WORKSPACE}/${vpc_name}"

  if ! g3kubectl get secrets/peregrine-secret > /dev/null 2>&1; then
    g3kubectl create secret generic peregrine-secret "--from-file=wsgi.py=${GEN3_HOME}/apis_configs/peregrine_settings.py" "--from-file=${GEN3_HOME}/apis_configs/config_helper.py"
  fi
fi

# ETL mapping file for tube
ETL_MAPPING_PATH="$(dirname $(g3k_manifest_path))/etlMapping.yaml"
if [[ -f "$ETL_MAPPING_PATH" ]]; then
  gen3 update_config etl-mapping "$ETL_MAPPING_PATH"
fi

if [[ -f "${WORKSPACE}/${vpc_name}/creds.json" ]]; then  # update secrets
  if [ ! -d "${WORKSPACE}/${vpc_name}" ]; then
    echo "${WORKSPACE}/${vpc_name} does not exist"
    exit 1
  fi

  cd "${WORKSPACE}/${vpc_name}"
  if ! g3kubectl get secret sheepdog-creds > /dev/null 2>&1; then
    credsFile=$(mktemp -p "$XDG_RUNTIME_DIR" "creds.json_XXXXXX")
    jq -r .sheepdog < creds.json > "$credsFile"
    g3kubectl create secret generic sheepdog-creds "--from-file=creds.json=${credsFile}"
  fi

  cd "${WORKSPACE}/${vpc_name}"

  if ! g3kubectl get secrets/sheepdog-secret > /dev/null 2>&1; then
    g3kubectl create secret generic sheepdog-secret "--from-file=wsgi.py=${GEN3_HOME}/apis_configs/sheepdog_settings.py" "--from-file=${GEN3_HOME}/apis_configs/config_helper.py"
  fi

  #
  # Create the 'sheepdog' and 'peregrine' postgres user if necessary
  #
  cd "${WORKSPACE}/${vpc_name}"

  if ! psql --help > /dev/null; then
    export DEBIAN_FRONTEND=noninteractive
    sudo -E apt install -y postgresql-client
  fi
  if ! jq --help > /dev/null; then
    export DEBIAN_FRONTEND=noninteractive
    sudo -E apt install -y jq
  fi

  gdcapi_db_user=$(jq -r .gdcapi.db_username < creds.json)
  gdcapi_db_password=$(jq -r .gdcapi.db_password < creds.json)
  sheepdog_db_user=$(jq -r .sheepdog.db_username < creds.json)
  sheepdog_db_password=$(jq -r .sheepdog.db_password < creds.json)
  peregrine_db_user=$(jq -r .peregrine.db_username < creds.json)
  gdcapi_db_host=$(jq -r .gdcapi.db_host < creds.json)
  gdcapi_db_database=$(jq -r .gdcapi.db_database < creds.json)
  export PGPASSWORD="$gdcapi_db_password"

  declare -a sqlList
  let tTooOld="$(date +%s) - 120"
  psqlFlagFile="${WORKSPACE}/${vpc_name}/.rendered_psql_users"
  # Avoid doing this over and over ...
  if [[ ! -f "$psqlFlagFile" || $(stat -c %Y "$psqlFlagFile") -lt "$tTooOld" ]]; then
    # Create peregrine and sheepdog db users if necessary
    for user in sheepdog peregrine; do
      new_db_user=$(jq -r .${user}.db_username < creds.json)
      new_db_password=$(jq -r .${user}.db_password < creds.json)

      if [[ "$gdcapi_db_user" != "$new_db_user" ]]; then
        new_user_count=$(psql -t -U $gdcapi_db_user -h $gdcapi_db_host -d $gdcapi_db_database -c "SELECT COUNT(*) FROM pg_catalog.pg_user WHERE usename='$new_db_user';")
        if [[ $new_user_count -eq 0 ]]; then
          echo "Creating postgres user $new_db_user"
          sql="CREATE USER $new_db_user WITH PASSWORD '$new_db_password';"
          echo "Running: $sql"
          psql -t -U $gdcapi_db_user -h $gdcapi_db_host -d $gdcapi_db_database -c "$sql"
        fi
      fi
    done

    # Grant permissions to peregrine
    sqlList=(
      "GRANT SELECT ON ALL TABLES IN SCHEMA public TO $peregrine_db_user;"
      "ALTER DEFAULT PRIVILEGES GRANT SELECT ON TABLES TO $peregrine_db_user;"
    );
    for sql in "${sqlList[@]}"; do
      echo "Running: $sql"
      psql -t -U $gdcapi_db_user -h $gdcapi_db_host -d $gdcapi_db_database -c "$sql" || true
    done

    # GRANT permissions to sheepdog
    declare -a sqlList;
    if [[ "$gdcapi_db_user" != "$sheepdog_db_user" ]]; then
      # sheepdog needs some extra permissions if it is not already the db owner
      sqlList=(
        "GRANT ALL ON ALL TABLES IN SCHEMA public TO $sheepdog_db_user;"
        "GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO $sheepdog_db_user;"
        "GRANT ALL ON SCHEMA public TO $sheepdog_db_user;"
        "ALTER DEFAULT PRIVILEGES GRANT ALL ON TABLES TO $sheepdog_db_user;"
        "ALTER DEFAULT PRIVILEGES GRANT ALL ON SEQUENCES TO $sheepdog_db_user;"
      );
      for sql in "${sqlList[@]}"; do
        echo "Running: $sql"
        psql -t -U $gdcapi_db_user -h $gdcapi_db_host -d $gdcapi_db_database -c "$sql" || true
      done
      # sheepdog user needs to grant peregrine privileges
      # on postgres stuff sheepdog creates in the future if sheepdog user is not the
      # same as the 'gdcapi' user - which is the case when migrating legacy commons ...
      sql="ALTER DEFAULT PRIVILEGES GRANT SELECT ON TABLES TO $peregrine_db_user;"
      echo "Running: $sql"
      PGPASSWORD="$sheepdog_db_password" psql -t -U "$sheepdog_db_user" -h $gdcapi_db_host -d $gdcapi_db_database -c "$sql" || true
    fi
    touch "$psqlFlagFile"
  fi

  # setup the database ...
  cd "${WORKSPACE}/${vpc_name}"
  if [[ ! -f .rendered_gdcapi_db ]]; then
    # job runs asynchronously ...
    gen3 job run gdcdb-create
    # also go ahead and setup the indexd auth secrets
    gen3 job run indexd-userdb
    echo "Sleep 10 seconds for gdcdb-create job"
    gen3 job logs gdcb-create || true
    gen3 job logs indexd-userdb || true
    echo "Leaving the job running in the background if not already done"
  fi
  # Avoid doing previous block more than once or when not necessary ...
  touch .rendered_gdcapi_db
fi
