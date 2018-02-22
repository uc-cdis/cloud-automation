#!/bin/bash
scriptDir=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")


patch_kube() {
    kubectl patch deployment $1 -p   "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
}

# 
# Patch replicas
patch_kreps() {
  if [[ -z "$1" || -z "$2" ]]; then
    echo "patch_kreps deployment-name replica-count"
    return 1
  fi
  kubectl patch deployment $1 -p  '{"spec":{"replicas":'$2'}}'
}

get_pod() {
    pod=$(kubectl get pods --output=jsonpath='{range .items[*]}{.metadata.name}  {"\n"}{end}' | grep -m 1 $1)
    echo $pod
}

get_pods() {
  kubectl get pods --output=jsonpath='{range .items[*]}{.metadata.name}  {"\n"}{end}' | grep "$1"
}

update_config() {
    kubectl delete configmap $1
    kubectl create configmap $1 --from-file $2
}
