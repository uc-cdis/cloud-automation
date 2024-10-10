source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

setup_gen3_workflow_infra() {
  gen3_log_info "setting up gen3-workflow"

  # create the gen3-workflow database and config file if they don't already exist
  # Note: `gen3_db_service_setup` doesn't allow '-' in the database name, so the db and secret
  # name are 'gen3workflow' and not 'gen3-workflow'
  if g3kubectl describe secret gen3workflow-g3auto > /dev/null 2>&1; then
    gen3_log_info "gen3workflow-g3auto secret already configured"
    return 0
  fi
  if [[ -n "$JENKINS_HOME" || ! -f "$(gen3_secrets_folder)/creds.json" ]]; then
    gen3_log_err "skipping db setup in non-adminvm environment"
    return 0
  fi
  # setup config file that gen3-workflow consumes
  local secretsFolder="$(gen3_secrets_folder)/g3auto/gen3workflow"
  if [[ ! -f "$secretsFolder/gen3-workflow-config.yaml" ]]; then
    # NOTE: We may not need a DB for this service. Leaving it in until the design is finalized.
    # if [[ ! -f "$secretsFolder/dbcreds.json" ]]; then
    #   if ! gen3 db setup gen3workflow; then
    #     gen3_log_err "Failed setting up database for gen3-workflow service"
    #     return 1
    #   fi
    # fi
    # if [[ ! -f "$secretsFolder/dbcreds.json" ]]; then
    #   gen3_log_err "dbcreds not present in Gen3Secrets/"
    #   return 1
    # fi

    cat - > "$secretsFolder/gen3-workflow-config.yaml" <<EOM
# Server

DEBUG: false
EOM
# DB_HOST: $(jq -r .db_host < "$secretsFolder/dbcreds.json")
# DB_USER: $(jq -r .db_username < "$secretsFolder/dbcreds.json")
# DB_PASSWORD: $(jq -r .db_password < "$secretsFolder/dbcreds.json")
# DB_DATABASE: $(jq -r .db_database < "$secretsFolder/dbcreds.json")
# EOM
  fi
  gen3 secrets sync 'setup gen3workflow-g3auto secrets'
}

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

  local role_name="funnel-role" # hardcoded in `role.yml`
  gen3_log_info "Recreating funnel role..."
  if g3kubectl get role $role_name -n $namespace > /dev/null 2>&1; then
    g3kubectl delete role $role_name -n $namespace
  fi
  g3kubectl create -f "${GEN3_HOME}/kube/services/funnel/role.yml" -n $namespace

  local role_binding_name="funnel-rolebinding" # hardcoded in `role-binding.yml`
  gen3_log_info "Recreating funnel role binding..."
  if g3kubectl get rolebinding $role_binding_name -n $namespace > /dev/null 2>&1; then
    g3kubectl delete rolebinding $role_binding_name -n $namespace
  fi
  g3kubectl create -f "${GEN3_HOME}/kube/services/funnel/role-binding.yml" -n $namespace

  g3kubectl apply -f "${GEN3_HOME}/kube/services/funnel/pvc.yml"

  # TODO move s3 bucket setup to `setup_gen3_workflow_infra`, or remove it if we use per-user buckets
  gen3_log_info "Setting up S3 bucket"
  hostname="$(gen3 api hostname)"
  bucket_name="ga4ghtes-${hostname//./-}"
  gen3 s3 create "$bucket_name" || true
  # TODO For some reason granting the SA access to the bucket is not needed. Maybe because it's
  #      in the same AWS account?
  # username="funnel-bot-${hostname//./-}"
  # gen3 awsrole create ${username} $sa_name || true
  # gen3 s3 attach-bucket-policy "$bucket_name" --read-write --role-name ${username} || true
}

if ! setup_gen3_workflow_infra; then
  gen3_log_err "kube-setup-gen3-workflow bailing out - failed to set up gen3-workflow infrastructure"
  exit 1
fi
gen3 roll gen3-workflow
g3kubectl apply -f "${GEN3_HOME}/kube/services/gen3-workflow/gen3-workflow-service.yaml"
gen3_log_info "The gen3-workflow service has been deployed onto the kubernetes cluster."

if g3k_manifest_lookup .versions.funnel 2> /dev/null; then
  if ! setup_funnel_infra; then
    gen3_log_err "kube-setup-gen3-workflow bailing out - failed to set up funnel infrastructure"
    exit 1
  fi
  gen3 roll funnel
  g3kubectl apply -f "${GEN3_HOME}/kube/services/funnel/funnel-service.yml"
  gen3_log_info "The funnel service has been deployed onto the kubernetes cluster."
else
  gen3_log_warn "not deploying funnel - no manifest entry for .versions.funnel. The gen3-workflow service may not work!"
fi
