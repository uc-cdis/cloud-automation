#!/bin/bash
#
# Deploy k8s metrics server - required for k8s horizontal pod autoscaling
#  gen3 help kube-setup-metrics
#  https://docs.aws.amazon.com/eks/latest/userguide/metrics-server.html
#  https://kubernetes.io/docs/tasks/debug-application-cluster/resource-metrics-pipeline/#metrics-server
#  https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/
#
# Note: you may need to run terraform (it has been patched)
#     to update the security groups
#     on the node pools to allow the control plane to access the
#     metrics server
#
#   kubectl get apiservices.apiregistration.k8s.io
#    

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

DESIRED_VERSION=0.6.2
CURRENT_VERSION=$(kubectl get deployment -n kube-system metrics-server -o json | jq -r .spec.template.spec.containers[0].image | awk -F :v '{print $2}')

gen3_metrics_deploy() {
  if [[ "$(gen3 db namespace)" == "default" && ($DESIRED_VERSION != $CURRENT_VERSION) ]]; then
    (
      g3kubectl apply -f "${GEN3_HOME}/kube/services/metrics-server/" -n kube-system
    )
  else
    gen3_log_info "not deploying metrics outside default namespace, or current version ($CURRENT_VERSION) matches desired version ($DESIRED_VERSION)"
  fi
}

gen3_metrics_check() {
  [[ "True" == "$(g3kubectl get apiservices.apiregistration.k8s.io v1beta1.metrics.k8s.io -o json 2> /dev/null | jq -e -r '.status.conditions | map(.key=.type | .value=.status) | from_entries | .Available' 2> /dev/null)" ]]
}

command="$1"
shift
case "$command" in
  "deploy"):
    gen3_metrics_deploy "$@"
    ;;
  "check"):
    gen3_metrics_check "$@"
    ;; 
  *)
    gen3_log_err "unknown option: $command"
    gen3 help kube-setup-metrics
    ;;
esac
