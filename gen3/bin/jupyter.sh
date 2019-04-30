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
# User namespace where jupyter notebooks run.
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

  gen3_jupyter_prepuller | g3kubectl apply -f -
}

# main ----------------------

command="$1"
shift
case "$command" in
  "j-namespace")
    gen3_jupyter_namespace "$@";
    ;;
  "prepuller")
    gen3_jupyter_prepuller "$@"
    ;;
  "upgrade")
    gen3_jupyter_upgrade "$@"
    ;;
  *)
    gen3_db_help
    ;;
esac
exit $?
