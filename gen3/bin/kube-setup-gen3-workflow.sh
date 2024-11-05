source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

setup_funnel_infra() {
  gen3_log_info "setting up funnel"
  helm repo add ohsu https://ohsu-comp-bio.github.io/helm-charts
  helm repo update ohsu

  local namespace="$(gen3 db namespace)"
  helm upgrade --install funnel ohsu/funnel --namespace $namespace
}

setup_gen3_workflow_infra() {
  gen3_log_info "setting up gen3-workflow"

  # create the gen3-workflow config file if it doesn't already exist
  # Note: `gen3_db_service_setup` doesn't allow '-' in the database name, so the db and secret
  # name are 'gen3workflow' and not 'gen3-workflow'. If we need a db later, we'll run `gen3 db
  # setup gen3workflow`
  if g3kubectl describe secret gen3workflow-g3auto > /dev/null 2>&1; then
    gen3_log_info "gen3workflow-g3auto secret already configured"
    return 0
  fi
  if [[ -n "$JENKINS_HOME" || ! -f "$(gen3_secrets_folder)/creds.json" ]]; then
    gen3_log_err "skipping config file setup in non-adminvm environment"
    return 0
  fi
  # setup config file that gen3-workflow consumes
  local secretsFolder="$(gen3_secrets_folder)/g3auto/gen3workflow"
  if [[ ! -f "$secretsFolder/gen3-workflow-config.yaml" ]]; then
    cat - > "$secretsFolder/gen3-workflow-config.yaml" <<EOM
# Server

DEBUG: false
EOM
  fi
  gen3 secrets sync 'setup gen3workflow-g3auto secrets'
}

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

if ! setup_gen3_workflow_infra; then
  gen3_log_err "kube-setup-gen3-workflow bailing out - failed to set up gen3-workflow infrastructure"
  exit 1
fi
gen3 roll gen3-workflow
g3kubectl apply -f "${GEN3_HOME}/kube/services/gen3-workflow/gen3-workflow-service.yaml"
gen3_log_info "The gen3-workflow service has been deployed onto the kubernetes cluster."
