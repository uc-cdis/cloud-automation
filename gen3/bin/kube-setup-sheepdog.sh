#!/bin/bash
#
# Deploy sheepdog into existing commons - assume configs are already configured
# for sheepdog to re-use the userapi db.
# This fragment is pasted into kube-services.sh by kube.tf.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

[[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets
(
  version="$(g3kubectl get secrets/sheepdog-secret -ojson 2> /dev/null | jq -r .metadata.labels.g3version)"
  if [[ -z "$version" || "$version" == null || "$version" -lt 2 ]]; then
    g3kubectl delete secret sheepdog-secret > /dev/null 2>&1 || true
    g3kubectl create secret generic sheepdog-secret "--from-file=wsgi.py=${GEN3_HOME}/apis_configs/sheepdog_settings.py" "--from-file=${GEN3_HOME}/apis_configs/config_helper.py"
    g3kubectl label secret sheepdog-secret g3version=2
  fi
)

if [[ -z "$JENKINS_HOME" && -f "$(gen3_secrets_folder)/creds.json" ]]; then
  cd "$(gen3_secrets_folder)"
  #
  # Create the 'sheepdog' and 'peregrine' postgres user if necessary
  #

  gdcapi_db_user=$(jq -r .gdcapi.db_username < creds.json)
  gdcapi_db_password=$(jq -r .gdcapi.db_password < creds.json)
  sheepdog_db_user=$(jq -r .sheepdog.db_username < creds.json)
  sheepdog_db_password=$(jq -r .sheepdog.db_password < creds.json)
  peregrine_db_user=$(jq -r .peregrine.db_username < creds.json)
  gdcapi_db_host=$(jq -r .gdcapi.db_host < creds.json)
  gdcapi_db_database=$(jq -r .gdcapi.db_database < creds.json)
  export PGPASSWORD="$gdcapi_db_password"

  declare -a sqlList
  # Avoid doing this over and over ...
  if gen3_time_since postgres_checkup is 120; then
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
  fi

  if [[ ! -f "$(gen3_secrets_folder)/.rendered_gdcapi_db" ]]; then
      # job runs asynchronously ...
      gen3 job run gdcdb-create
      gen3_log_info "Sleep 10 seconds for gdcdb-create job"
      sleep 10
      gen3 job logs gdcb-create || true
      gen3_log_info "Leaving the jobs running in the background if not already done"
      touch "$(gen3_secrets_folder)/.rendered_gdcapi_db"
  fi
fi

# deploy sheepdog 
gen3 roll sheepdog
g3kubectl apply -f "${GEN3_HOME}/kube/services/sheepdog/sheepdog-service.yaml"
gen3 roll sheepdog-canary || true
g3kubectl apply -f "${GEN3_HOME}/kube/services/sheepdog/sheepdog-canary-service.yaml"

cat <<EOM
The sheepdog services has been deployed onto the k8s cluster.
EOM
