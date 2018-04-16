#!/bin/bash
#
# Deploy sheepdog into existing commons - assume configs are already configured
# for sheepdog to re-use the userapi db.
# This fragment is pasted into kube-services.sh by kube.tf.
#

set -e

_KUBE_SETUP_SHEEPDOG=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
# Jenkins friendly
export WORKSPACE="${WORKSPACE:-$HOME}"
export GEN3_HOME="${GEN3_HOME:-$(cd "${_KUBE_SETUP_SHEEPDOG}/../.." && pwd)}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"

if [[ -z "$_KUBES_SH" ]]; then
  source "$GEN3_HOME/kube/kubes.sh"
fi # else already sourced this file ...

export RENDER_CREDS="${GEN3_HOME}/tf_files/configs/render_creds.py"

if [ ! -f "${RENDER_CREDS}" ]; then
  echo "ERROR: ${RENDER_CREDS} does not exist"
fi

vpc_name=${vpc_name:-$1}
if [ -z "${vpc_name}" ]; then
   echo "Usage: bash kube-setup-sheepdog.sh vpc_name"
   exit 1
fi

if [[ -z "$(g3kubectl get configmaps/global -o=jsonpath='{.data.dictionary_url}')" ]]; then
  echo "ERROR: configmaps/global does not include dictionary_url"
  echo "... update and apply ${vpc_name}/00configmap.json, then retry this script"
  exit 1
fi

if [[ ! -f "${WORKSPACE}/${vpc_name}_output/creds.json" ]]; then  # probably in Jenkins ...
  echo "WARNING: ${WORKSPACE}/${vpc_name}_output does not exist - not setting secrets"
fi
if [[ -f "${WORKSPACE}/${vpc_name}_output/creds.json" ]]; then  # update secrets
  if [ ! -d "${WORKSPACE}/${vpc_name}" ]; then
    echo "${WORKSPACE}/${vpc_name} does not exist"
    exit 1
  fi

  cd "${WORKSPACE}/${vpc_name}_output"
  python "${RENDER_CREDS}" secrets

  if ! g3kubectl get secret sheepdog-creds > /dev/null 2>&1; then
    credsFile=$(mktemp -p "$XDG_RUNTIME_DIR" "creds.json_XXXXXX")
    jq -r .sheepdog < creds.json > "$credsFile"
    g3kubectl create secret generic sheepdog-creds "--from-file=creds.json=${credsFile}"
  fi

  cd "${WORKSPACE}/${vpc_name}"

  if ! g3kubectl get secrets/sheepdog-secret > /dev/null 2>&1; then
    g3kubectl create secret generic sheepdog-secret --from-file=wsgi.py=./apis_configs/sheepdog_settings.py
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
fi

# deploy sheepdog 
g3k roll sheepdog

if [[ -d "${WORKSPACE}/${vpc_name}_output" ]]; then  # setup the database ...
  cd "${WORKSPACE}/${vpc_name}"

  #
  # Note: the 'create_gdcapi_db' flag is set in
  #   kube-services.sh
  #   The assumption here is that we only create the db once -
  #   when we run 'kube-services.sh' at cluster init time
  #   This setup block is not necessary when migrating an existing userapi commons to fence.
  #
  if [[ -z "${gdcapi_snapshot}" && "${create_gdcapi_db}" = "true" && ( ! -f .rendered_gdcapi_db ) ]]; then
    cd "${WORKSPACE}/${vpc_name}_output"
    python "${RENDER_CREDS}" gdcapi_db
    cd "${WORKSPACE}/${vpc_name}"
    # force restart - might not be necessary
    g3k roll sheepdog
  fi
  # Avoid doing previous block more than once or when not necessary ...
  touch .rendered_gdcapi_db
fi

g3kubectl apply -f "${GEN3_HOME}/kube/services/sheepdog/sheepdog-service.yaml"

cat <<EOM
The sheepdog services has been deployed onto the k8s cluster.
EOM
