# TODO add funnel to roll-all
source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

setup_funnel_infra() {
  gen3_log_info "setting up funnel"
  local namespace="$(gen3 db namespace)"

  # replace the cluster IP placeholder with the actual cluster IP
  # TODO Following the funnel deployment doc, but this is probably not the best way to do this.
  #      Does the ip even stay the same long-term?
  g3kubectl apply -f "${GEN3_HOME}/kube/services/funnel/funnel-service.yml"
  funnelClusterIp="$(g3kubectl get services funnel-service --output=json | jq -r '.spec.clusterIP')"
  gen3_log_info "Funnel cluster IP: $funnelClusterIp"
  tempWorkerConfig="$(mktemp "$XDG_RUNTIME_DIR/funnel-worker-config.yml_XXXXXX")"
  sed "s/FUNNEL_SERVICE_CLUSTER_IP_PLACEHOLDER/$funnelClusterIp/" ${GEN3_HOME}/kube/services/funnel/funnel-worker-config.yml > $tempWorkerConfig

  # TODO add to funnel-worker-config.yml:
  # AmazonS3:
  #   Disabled: false
  #   MaxRetries: 3
  #   Key: ""
  #   Secret: ""

  # set the namespace in the server config
  tempServerConfig="$(mktemp "$XDG_RUNTIME_DIR/funnel-server-config.yml_XXXXXX")"
  g3k_kv_filter ${GEN3_HOME}/kube/services/funnel/funnel-server-config.yml FUNNEL_SERVICE_NAMESPACE_PLACEHOLDER "$namespace" > $tempServerConfig

  local configmap_name="funnel-config"
  gen3_log_info "Recreating funnel configmap..."
  if g3kubectl get configmap $configmap_name -n $namespace > /dev/null 2>&1; then
    g3kubectl delete configmap $configmap_name -n $namespace
  fi
  g3kubectl create configmap $configmap_name -n $namespace --from-file="funnel-server-config.yml=$tempServerConfig" --from-file="funnel-worker-config.yml=$tempWorkerConfig"
  rm $tempWorkerConfig $tempServerConfig # delete temp files

  local sa_name="funnel-sa"
  gen3_log_info "Recreating funnel SA..."
  if g3kubectl get serviceaccount $sa_name -n $namespace > /dev/null 2>&1; then
    g3kubectl delete serviceaccount $sa_name -n $namespace
  fi
  g3kubectl create serviceaccount $sa_name -n $namespace

  local role_name="funnel-role" # hardcoded in `funnel-role.yml`
  gen3_log_info "Recreating funnel role..."
  if g3kubectl get role $role_name -n $namespace > /dev/null 2>&1; then
    g3kubectl delete role $role_name -n $namespace
  fi
  g3kubectl create -f "${GEN3_HOME}/kube/services/funnel/funnel-role.yml" -n $namespace

  local role_binding_name="funnel-rolebinding" # hardcoded in `funnel-role-binding.yml`
  gen3_log_info "Recreating funnel role binding..."
  if g3kubectl get rolebinding $role_binding_name -n $namespace > /dev/null 2>&1; then
    g3kubectl delete rolebinding $role_binding_name -n $namespace
  fi
  g3kubectl create -f "${GEN3_HOME}/kube/services/funnel/funnel-role-binding.yml" -n $namespace


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
g3kubectl apply -f "${GEN3_HOME}/kube/services/funnel/funnel-service.yml"

gen3_log_info "The funnel service has been deployed onto the kubernetes cluster."
