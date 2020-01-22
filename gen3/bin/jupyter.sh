source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


# lib --------------------------

# 
# Extend the prepuller yaml with data from the manifest
#
# @param varargs img1 img2 ... - additional images as args - mostly to support testing
#
gen3_jupyter_prepuller() {
  local images
  local it
  images="$@"
  if g3kubectl get configmap manifest-jupyterhub > /dev/null 2>&1; then
    images="$images $(g3kubectl get configmap manifest-jupyterhub -ojson | jq -r '.data.containers // "[]" | fromjson | map(.image) | .[]')"
  fi

  cat "${GEN3_HOME}/kube/services/jupyterhub/jupyterhub-prepuller.yaml"
  if [[ -n "$images" ]]; then
    local count=0
    for it in ${images}; do
      cat - <<EOM
      - name: "image-${count}"
        image: $it
        imagePullPolicy: IfNotPresent
        command:
          - /bin/sh
          - -c
          - echo 'Pulling complete'
EOM
      count=$((count+1))
    done
  fi
}


#
# Echo the user namespace where jupyter notebooks run.
#
gen3_jupyter_namespace() {
  local notebookNamespace
  local namespace
  # If you change this name you need to change it in the kube/.../jupyterhub-config.py too
  notebookNamespace="jupyter-pods"
  namespace="$(gen3 db namespace)"
  if [[ -n "$namespace" && "$namespace" != "default" ]]; then
    notebookNamespace="jupyter-pods-$namespace"
  fi
  echo "$notebookNamespace"
}

#
# Create and label the jupyter namespace, also label the gen3 workspace
#
gen3_jupyter_namespace_setup() {
  local notebookNamespace
  local namespace
  
  # avoid doing this overly often
  if gen3_time_since jupyter_setup is 300; then
    namespace="$(gen3 db namespace)"
    notebookNamespace="$(gen3_jupyter_namespace)"

    if ! g3kubectl get namespace "$notebookNamespace" > /dev/null 2>&1; then
      gen3_log_info "gen3_jupyter_namespace_setup" "creating k8s namespace: ${notebookNamespace}" 
      g3kubectl create namespace "${notebookNamespace}"
    else
      gen3_log_info "gen3_jupyter_namespace_setup" "I think k8s namespace ${notebookNamespace} already exists"
    fi
    g3kubectl label namespace "${notebookNamespace}" "role=usercode" > /dev/null 2>&1 || true
    g3kubectl label namespace "${namespace}" "role=gen3" > /dev/null 2>&1 || true
  else
    gen3_log_info "Skipping jupyter namespace setup - already did it in last 5 minutes"
  fi
}


#
# Update the jupyterhub configmaps,
# update the prepuller, 
# and restart jupyter hub
#
gen3_jupyter_upgrade() {
  local notebookNamespace
  notebookNamespace="$(gen3_jupyter_namespace)"
  if ! g3kubectl get namespace "$notebookNamespace" > /dev/null 2>&1; then
    gen3_log_err "gen3_jupyter_upgrade" "refusing to upgrade jupyter - namespace does not exist $notebookNamespace"
    return 1
  fi
  
  gen3 gitops configmaps
  gen3 update_config jupyterhub-config "${GEN3_HOME}/kube/services/jupyterhub/jupyterhub_config.py"

  if g3kubectl get statefulset jupyterhub-deployment; then 
    g3kubectl delete statefulset jupyterhub-deployment || true
  fi
  if g3kubectl get daemonset jupyterhub-prepuller; then
    g3kubectl delete daemonset jupyterhub-prepuller || true
  fi
  gen3 roll jupyterhub

  local namespace
  namespace="$(gen3 db namespace)"
  if [[ "$namespace" == "default" ]]; then
    # avoid deploying prepuller in dev/qa namespaces ...
    gen3_jupyter_prepuller | g3kubectl apply -f -
  fi
}

# main ----------------------

command="$1"
shift
case "$command" in
  "j-namespace")
    if [[ $# -gt 0 && "$1" == "setup" ]]; then
      shift
      gen3_jupyter_namespace_setup "$@";
    else
      gen3_jupyter_namespace "$@";
    fi
    ;;
  "prepuller")
    gen3_jupyter_prepuller "$@"
    ;;
  "upgrade")
    gen3_jupyter_upgrade "$@"
    ;;
  *)
    gen3 help jupyter
    ;;
esac
exit $?
