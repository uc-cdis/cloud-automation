source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


setup_database_and_config() {
  gen3_log_info "setting up orthanc DB and config"

  if g3kubectl describe secret orthanc-g3auto > /dev/null 2>&1; then
    gen3_log_info "orthanc-g3auto secret already configured"
    return 0
  fi
  if [[ -n "$JENKINS_HOME" || ! -f "$(gen3_secrets_folder)/creds.json" ]]; then
    gen3_log_err "skipping db setup in non-adminvm environment"
    return 0
  fi

  # Setup config file that orthanc consumes
  local secretsFolder="$(gen3_secrets_folder)/g3auto/orthanc"
  if [[ ! -f "$secretsFolder/orthanc_postgres.json" ]]; then
    if [[ ! -f "$secretsFolder/dbcreds.json" ]]; then
      if ! gen3 db setup orthanc; then
        gen3_log_err "Failed setting up database for orthanc"
        return 1
      fi
    fi
    if [[ ! -f "$secretsFolder/dbcreds.json" ]]; then
      gen3_log_err "dbcreds not present in Gen3Secrets/"
      return 1
    fi

    # TODO: generate and mount a cert
    # "SslEnabled": true,
    # "SslCertificate": ""
    cat - > "$secretsFolder/orthanc_postgres.json" <<EOM
{
  "PostgreSQL": {
    "EnableIndex": true,
    "EnableStorage": true,
    "Port": 5432,
    "Host": "$(jq -r .db_host < $secretsFolder/dbcreds.json)",
    "Database": "$(jq -r .db_database < $secretsFolder/dbcreds.json)",
    "Username": "$(jq -r .db_username < $secretsFolder/dbcreds.json)",
    "Password": "$(jq -r .db_password < $secretsFolder/dbcreds.json)"
  }
}
EOM
  fi
  gen3 secrets sync 'setup orthanc-g3auto secrets'
}

if ! setup_database_and_config; then
  gen3_log_err "kube-setup-orthanc bailing out - database/config failed setup"
  exit 1
fi

gen3 roll orthanc
g3kubectl apply -f "${GEN3_HOME}/kube/services/orthanc/orthanc-service.yaml"

# TODO dicom-viewer setup in its own file
#gen3 roll viewer
#g3kubectl apply -f "${GEN3_HOME}/kube/services/viewer/viewer-service.yaml"

cat <<EOM
The orthanc service has been deployed onto the k8s cluster.
EOM

