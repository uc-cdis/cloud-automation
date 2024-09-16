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

  # set the namespace in the server config
  tempServerConfig="$(mktemp "$XDG_RUNTIME_DIR/funnel-server-config.yml_XXXXXX")"
  sed "s/FUNNEL_SERVICE_NAMESPACE_PLACEHOLDER/$namespace/" ${GEN3_HOME}/kube/services/funnel/funnel-server-config.yml > $tempServerConfig

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

  gen3_log_info "Setting up funnel SA with access to S3"
  hostname="$(gen3 api hostname)"
  bucket_name="ga4ghtes-${hostname//./-}"
  gen3 s3 create "$bucket_name" || true
  # TODO For some reason granting the SA access to the bucket is not needed. Maybe because it's
  #      in the same AWS account?
  # username="funnel-bot-${hostname//./-}"
  # gen3 awsrole create ${username} $sa_name || true
  # gen3 s3 attach-bucket-policy "$bucket_name" --read-write --role-name ${username} || true
}

if ! setup_funnel_infra; then
  gen3_log_err "kube-setup-funnel bailing out - failed to set up infrastructure"
  exit 1
fi

gen3 roll funnel
g3kubectl apply -f "${GEN3_HOME}/kube/services/funnel/funnel-service.yml"

gen3_log_info "The funnel service has been deployed onto the kubernetes cluster."
