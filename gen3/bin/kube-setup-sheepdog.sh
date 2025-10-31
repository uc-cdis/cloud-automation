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
  creds="$(gen3 db creds peregrine)"
  peregrine_db_user="$(jq -r .db_username <<<"$creds")"
  server="$(jq -r .g3FarmServer <<<"$creds")"

  new_user_count="$(gen3 psql "$server" -t -c "SELECT COUNT(*) FROM pg_catalog.pg_user WHERE usename='$peregrine_db_user';")"
  if [[ $new_user_count -eq 0 ]]; then
    gen3_log_info "Creating postgres user $peregrine_db_user"    
    new_db_password="$(jq -r .db_password <<<"$creds")"
    sql="CREATE USER $peregrine_db_user WITH PASSWORD '$new_db_password';"
    gen3 psql "$server" -c "$sql"
  else
    gen3_log_info "peregrine user already exists"
  fi

  declare -a sqlList
  # Avoid doing this over and over ...
  if gen3_time_since postgres_checkup is 120; then
    # Grant permissions to peregrine
    sqlList=(
      "GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"$peregrine_db_user\";"
      "ALTER DEFAULT PRIVILEGES GRANT SELECT ON TABLES TO \"$peregrine_db_user\";"
    );
    for sql in "${sqlList[@]}"; do
      gen3_log_info "Running: $sql"
      gen3 psql sheepdog -c "$sql" || true
    done
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
The sheepdog service has been deployed onto the k8s cluster.
EOM
