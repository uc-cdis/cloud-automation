source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

setup_database_and_config() {
  gen3_log_info "setting up dicom-server DB and config"

  if g3kubectl describe secret orthanc-g3auto > /dev/null 2>&1; then
    gen3_log_info "orthanc-g3auto secret already configured"
    return 0
  fi
  if [[ -n "$JENKINS_HOME" || ! -f "$(gen3_secrets_folder)/creds.json" ]]; then
    gen3_log_err "skipping db setup in non-adminvm environment"
    return 0
  fi

  # Setup config files that dicom-server consumes
  local secretsFolder="$(gen3_secrets_folder)/g3auto/orthanc"
  if [[ ! -f "$secretsFolder/orthanc_config_overwrites.json" ]]; then
    if [[ ! -f "$secretsFolder/dbcreds.json" ]]; then
      if ! gen3 db setup orthanc; then
        gen3_log_err "Failed setting up orthanc database for dicom-server"
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
    cat - > "$secretsFolder/orthanc_config_overwrites.json" <<EOM
{ 
  "AuthenticationEnabled": false,
  "PostgreSQL": {
    "EnableIndex": true,
    "EnableStorage": true,
    "Port": 5432,
    "Host": "$(jq -r .db_host < $secretsFolder/dbcreds.json)",
    "Database": "$(jq -r .db_database < $secretsFolder/dbcreds.json)",
    "Username": "$(jq -r .db_username < $secretsFolder/dbcreds.json)",
    "Password": "$(jq -r .db_password < $secretsFolder/dbcreds.json)",
    "IndexConnectionsCount": 5,
    "Lock": false
  },
  "PythonScript": "/etc/orthanc/authz_filter.py"
}
EOM
  fi
  gen3 secrets sync 'setup orthanc-g3auto secrets'
}

if ! setup_database_and_config; then
  gen3_log_err "kube-setup-dicom-server bailing out - database/config failed setup"
  exit 1
fi

gen3 roll dicom-server
g3kubectl apply -f "${GEN3_HOME}/kube/services/dicom-server/dicom-server-service.yaml"

cat <<EOM
The dicom-server service has been deployed onto the k8s cluster.
EOM
