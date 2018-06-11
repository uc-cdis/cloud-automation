#!/bin/bash
#
# Initializes the Gen3 k8s secrets and services.
#
# Note that kube.tf cat's this file into ${vpc_name}_output/kube-services.sh,
# but can also run this standalone if the environment is
# properly configured.
#
set -e

_KUBE_SETUP_SECRETS=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
source "${_KUBE_SETUP_SECRETS}/../lib/kube-setup-init.sh"

mkdir -p "${WORKSPACE}/${vpc_name}/apis_configs"

if [[ -f "${WORKSPACE}/${vpc_name}_output/creds.json" ]]; then # update secrets
  #
  # Setup the files that will become secrets in "${WORKSPACE}/$vpc_name/apis_configs"
  #
  cd "${WORKSPACE}"/${vpc_name}_output

  # Note: look into 'kubectl replace' if you need to replace a secret
  if ! g3kubectl get secrets/indexd-secret > /dev/null 2>&1; then
    g3kubectl create secret generic indexd-secret --from-file=local_settings.py="${GEN3_HOME}/apis_configs/indexd_settings.py" "--from-file=${GEN3_HOME}/apis_configs/config_helper.py"
  fi
  if ! g3kubectl get secret indexd-creds > /dev/null 2>&1; then
    credsFile=$(mktemp -p "$XDG_RUNTIME_DIR" "creds.json_XXXXXX")
    jq -r .indexd < creds.json > "$credsFile"
    g3kubectl create secret generic indexd-creds "--from-file=creds.json=${credsFile}"
  fi

  if [[ ! -f "${WORKSPACE}"/${vpc_name}/apis_configs/user.yaml ]]; then
    # user database for accessing the commons ...
    cp "${GEN3_HOME}/apis_configs/user.yaml" "${WORKSPACE}"/${vpc_name}/apis_configs/
  fi

  cd "${WORKSPACE}"/${vpc_name}
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
  g3kubectl create configmap config-helper --from-file "${GEN3_HOME}/apis_configs/config_helper.py"
fi

if [[ -f "${WORKSPACE}/${vpc_name}_output/creds.json" ]]; then # update fence secrets
  if [ ! -d "${WORKSPACE}/${vpc_name}" ]; then
    echo "${WORKSPACE}/${vpc_name} does not exist"
    exit 1
  fi

  cd "${WORKSPACE}/${vpc_name}_output"

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

  if [ ! -f jwt-keys/jwt_public_key.pem ]; then
    openssl genrsa -out jwt-keys/jwt_private_key.pem 2048
    openssl rsa -in jwt-keys/jwt_private_key.pem -pubout -out jwt-keys/jwt_public_key.pem
  fi

  # sftp key
  if [ ! -f ssh-keys/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -C "dev@test.com" -N "" -f ssh-keys/id_rsa
  fi

  if ! g3kubectl get configmaps/fence > /dev/null 2>&1; then
    g3kubectl create configmap fence --from-file=apis_configs/user.yaml
  fi

  if ! g3kubectl get secrets/fence-config > /dev/null 2>&1; then
    # load updated fence-user-config.yaml into secret if it exists
    if g3kubectl get secrets/fence-user-config > /dev/null 2>&1; then
      echo "loading fence config from file..."
      fence_config=${WORKSPACE}/${vpc_name}/apis_configs/fence-user-config.yaml
      g3kubectl delete secret fence-user-config
      g3kubectl create secret generic fence-user-config "--from-file=fence-user-config.yaml=${fence_config}"
    fi

    # run job to inject creds.json into fence-user-config.yaml and save as fence-config
    g3k runjob fence-config

    # dump fence-user-config secret into file so user can edit.
    let count=0
    while [[ ! -f g3kubectl get secrets/fence-config > /dev/null 2>&1 && $count -lt 50 ]]; do
      echo "waiting for fence-config...";
      sleep 2
      let count=$count+1
    done
    if [[ ! -f g3kubectl get secrets/fence-config > /dev/null 2>&1 ]]; then
      echo "dumping fence config into file from fence-user-config secret..."
      fence_config=${WORKSPACE}/${vpc_name}/apis_configs/fence-user-config.yaml
      g3kubectl get secrets/fence-user-config -o json | jq -r '.data["fence-user-config.yaml"]' | base64 --decode > "${fence_config}"
    else
      echo "ERROR: could not find fence-config within the timeout!"
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

  if ! kubectl get secrets/fence-jwt-keys > /dev/null 2>&1; then
    g3kubectl create secret generic fence-jwt-keys --from-file=./jwt-keys
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

if [[ -f "${WORKSPACE}/${vpc_name}_output/creds.json" ]]; then # update peregrine secrets
  if [ ! -d "${WORKSPACE}/${vpc_name}" ]; then
    echo "${WORKSPACE}/${vpc_name} does not exist"
    exit 1
  fi

  cd "${WORKSPACE}/${vpc_name}_output"

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

if [[ -z "$(g3kubectl get configmaps/global -o=jsonpath='{.data.dictionary_url}')" ]]; then
  echo "ERROR: configmaps/global does not include dictionary_url"
  echo "... update and apply ${vpc_name}/00configmap.json, then retry this script"
  exit 1
fi

if [[ -f "${WORKSPACE}/${vpc_name}_output/creds.json" ]]; then  # update secrets
  if [ ! -d "${WORKSPACE}/${vpc_name}" ]; then
    echo "${WORKSPACE}/${vpc_name} does not exist"
    exit 1
  fi

  cd "${WORKSPACE}/${vpc_name}_output"
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
  cd "${WORKSPACE}/${vpc_name}_output"

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
    psql -t -U $gdcapi_db_user -h $gdcapi_db_host -d $gdcapi_db_database -c "$sql";
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
      psql -t -U $gdcapi_db_user -h $gdcapi_db_host -d $gdcapi_db_database -c "$sql";
    done
    # sheepdog user needs to grant peregrine privileges
    # on postgres stuff sheepdog creates in the future if sheepdog user is not the
    # same as the 'gdcapi' user - which is the case when migrating legacy commons ...
    sql="ALTER DEFAULT PRIVILEGES GRANT SELECT ON TABLES TO $peregrine_db_user;"
    echo "Running: $sql"
    PGPASSWORD="$sheepdog_db_password" psql -t -U "$sheepdog_db_user" -h $gdcapi_db_host -d $gdcapi_db_database -c "$sql"
  fi
  # setup the database ...
  cd "${WORKSPACE}/${vpc_name}"
  if [[ ! -f .rendered_gdcapi_db ]]; then
    # job runs asynchronously ...
    g3k runjob gdcdb-create
    # also go ahead and setup the indexd auth secrets
    g3k runjob indexd-userdb
    echo "Sleep 10 seconds for gdcdb-create job"
    g3k joblogs gdcb-create || true
    g3k joblogs indexd-userdb || true
    echo "Leaving the job running in the background if not already done"
  fi
  # Avoid doing previous block more than once or when not necessary ...
  touch .rendered_gdcapi_db
fi
