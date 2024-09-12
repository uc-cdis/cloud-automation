source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

setup_funnel_infra() {
  gen3_log_info "setting up funnel"

  g3kubectl apply -f "${GEN3_HOME}/kube/services/funnel/funnel-service.yaml"

  # replace the cluster IP placeholder with the actual cluster IP
  funnelClusterIp="$(kubectl get services funnel-service --output=json | jq -r '.spec.clusterIP')"
  tempFile="$(mktemp "$XDG_RUNTIME_DIR/funnel-worker-config.yaml_XXXXXX")"
  sed "s/FUNNEL_SERVICE_CLUSTER_IP_PLACEHOLDER/$funnelClusterIp/" ${GEN3_HOME}/kube/services/funnel/funnel-worker-config.yaml > $tempFile

  # TODO add to funnel-worker-config.yaml:
  # AmazonS3:
  #   Disabled: false
  #   MaxRetries: 3
  #   Key: ""
  #   Secret: ""

  local namespace="$(gen3 db namespace)"
  local configmap_name="funnel-config"
  if kubectl get configmap $configmap_name -n $namespace > /dev/null 2>&1; then
    g3kubectl delete configmap $configmap_name -n $namespace
  fi
  g3kubectl create configmap $configmap_name -n $namespace --from-file="${GEN3_HOME}/kube/services/funnel/funnel-server-config.yaml" --from-file="$tempFile"
  rm "$tempFile"

  local sa_name="funnel-sa"
  if kubectl get serviceaccount $sa_name -n $namespace 2>&1; then
    g3kubectl delete serviceaccount $sa_name -n $namespace
  fi
  g3kubectl create serviceaccount $sa_name -n $namespace

  local role_name="funnel-role" # hardcoded in `funnel-role.yaml`
  if kubectl get role $role_name -n $namespace 2>&1; then
    g3kubectl delete role $role_name -n $namespace
  fi
  g3kubectl create -f "${GEN3_HOME}/kube/services/funnel/funnel-role.yaml" -n $namespace

  local role_binding_name="funnel-rolebinding" # hardcoded in `funnel-role-binding.yaml`
  if kubectl get rolebinding $role_binding_name -n $namespace 2>&1; then
    g3kubectl delete rolebinding $role_binding_name -n $namespace
  fi
  g3kubectl create -f "${GEN3_HOME}/kube/services/funnel/funnel-role-binding.yaml" -n $namespace


#   if g3kubectl describe secret orthanc-g3auto > /dev/null 2>&1; then
#     gen3_log_info "orthanc-g3auto secret already configured"
#     return 0
#   fi
#   if [[ -n "$JENKINS_HOME" || ! -f "$(gen3_secrets_folder)/creds.json" ]]; then
#     gen3_log_err "skipping db setup in non-adminvm environment"
#     return 0
#   fi

#   # Setup config files that dicom-server consumes
#   local secretsFolder="$(gen3_secrets_folder)/g3auto/orthanc"
#   if [[ ! -f "$secretsFolder/orthanc_config_overwrites.json" ]]; then
#     if [[ ! -f "$secretsFolder/dbcreds.json" ]]; then
#       if ! gen3 db setup orthanc; then
#         gen3_log_err "Failed setting up orthanc database for dicom-server"
#         return 1
#       fi
#     fi
#     if [[ ! -f "$secretsFolder/dbcreds.json" ]]; then
#       gen3_log_err "dbcreds not present in Gen3Secrets/"
#       return 1
#     fi

#     # TODO: generate and mount a cert
#     # "SslEnabled": true,
#     # "SslCertificate": ""
#     cat - > "$secretsFolder/orthanc_config_overwrites.json" <<EOM
# { 
#   "AuthenticationEnabled": false,
#   "PostgreSQL": {
#     "EnableIndex": true,
#     "EnableStorage": true,
#     "Port": 5432,
#     "Host": "$(jq -r .db_host < $secretsFolder/dbcreds.json)",
#     "Database": "$(jq -r .db_database < $secretsFolder/dbcreds.json)",
#     "Username": "$(jq -r .db_username < $secretsFolder/dbcreds.json)",
#     "Password": "$(jq -r .db_password < $secretsFolder/dbcreds.json)",
#     "IndexConnectionsCount": 5,
#     "Lock": false
#   },
#   "PythonScript": "/etc/orthanc/authz_filter.py"
# }
# EOM
#   fi
#   gen3 secrets sync 'setup orthanc-g3auto secrets'
}

if ! setup_funnel_infra; then
  gen3_log_err "kube-setup-funnel bailing out - failed to set up infrastructure"
  exit 1
fi

gen3 roll funnel
g3kubectl apply -f "${GEN3_HOME}/kube/services/funnel/funnel-service.yaml"

gen3_log_info "The funnel service has been deployed onto the kubernetes cluster."
