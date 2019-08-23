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


gen3_metrics_deploy() {
  if [[ "$(gen3 db namespace)" == "default" ]] && (! g3kubectl get deployment metrics-server --namespace kube-system > /dev/null 2>&1); then
    (
      cd "$XDG_RUNTIME_DIR"
      #DOWNLOAD_URL=$(curl --silent "https://api.github.com/repos/kubernetes-incubator/metrics-server/releases/latest" | jq -r .tarball_url)
      DOWNLOAD_URL="https://github.com/kubernetes-incubator/metrics-server/archive/v0.3.3.tar.gz"
      DOWNLOAD_VERSION=$(grep -o '[^/v]*$' <<< $DOWNLOAD_URL)
      curl -Ls "$DOWNLOAD_URL" -o metrics-server-$DOWNLOAD_VERSION.tar.gz
      mkdir metrics-server-$DOWNLOAD_VERSION
      tar -xzf metrics-server-$DOWNLOAD_VERSION.tar.gz --directory metrics-server-$DOWNLOAD_VERSION --strip-components 1
      export KUBECTL_NAMESPACE=kube-system
      g3kubectl apply -f metrics-server-$DOWNLOAD_VERSION/deploy/1.8+/
      /bin/rm -rf "metrics-server-$DOWNLOAD_VERSION"
    )
  else
    gen3_log_info "not deploying metrics outside default namespace"
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