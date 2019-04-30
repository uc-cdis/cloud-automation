source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


# 
# Extend the prepuller yaml with data from the manifest
#
gen3_jupyter_prepuller() {
  local configPath
  local images
  local prepulleryaml
  images=''
  if [[ g3kubectl get configmap manifest-jupyterhub > /dev/null 2>&1 ]]; then
    images="$(g3kubectl get configmap manifest-jupyterhub -ojson | jq -r '.data.containers | select(. != null)' )"
    if [[ "$images" == "null" ]]; then 
  configPath=$(g3k_manifest_path)
  if [[ "$configPath" =~ .json$ ]]; then
    images=($(jq -r -e ".jupyterhub.containers[].image" < "$configPath"))
  elif [[ "$configPath" =~ .yaml ]]; then
    images=($(yq -r -e ".jupyterhub.containers[].image" < "$configPath"))
  else
    gen3_log_err "gen3_jupyter_upgrade" "file is not .json or .yaml: $configPath)"
    return 1
  fi

  prepulleryaml=$(cat "${GEN3_HOME}/kube/services/jupyterhub/jupyterhub-prepuller.yaml")
  for key in "${!images[@]}"; do
    newimage="      - name: \"image-${key}\"
        image: ${images[$key]}
        imagePullPolicy: IfNotPresent
        command:
          - /bin/sh
          - -c
          - echo 'Pulling complete'"
    prepulleryaml="${prepulleryaml}"$'\n'"${newimage}"
  done
  echo "$prepulleryaml"
}


#
# Update the jupyterhub config.py,
# mount new manifest images, 
# update the prepuller, 
# and restart jupyter hub
#
gen3_jupyter_upgrade() {
  gen3 gitops configmaps

  if g3kubectl get statefulset jupyterhub-deployment; then 
    g3kubectl delete statefulset jupyterhub-deployment || true
  fi
  if g3kubectl get daemonset jupyterhub-prepuller; then
    g3kubectl delete daemonset jupyterhub-prepuller || true
  fi
  gen3 update_config jupyterhub-config "${GEN3_HOME}/kube/services/jupyterhub/jupyterhub_config.py"
  gen3 roll jupyterhub

  gen3_jupyter_prepuller | g3kubectl apply -f -
}



#
# User namespace where jupyter notebooks run
#
gen3_jupyter_namespace() {
  local notebookNamespace
  local namespace
  notebookNamespace="jupyter-pods"
  namespace="$(gen3 db namespace)"
  if [[ -n "$namespace" && "$namespace" != "default" ]]; then
    notebookNamespace="jupyter-pods-$namespace"
  fi
  echo "$notebookNamespace"
}


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