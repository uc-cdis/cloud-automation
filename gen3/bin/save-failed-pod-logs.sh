#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

help() {
  cat - <<EOM
  gen3 save-failed-pod-logs:
      Parse the pod listing and identify pods
      that failed either due to img pull errors
      or service startup issues.
      The kubectl output from the describe and logs
      commands are saved into log files to be archived
      by Jenkins and assist operators so they can
      quickly debug what went wrong with their pods.
EOM
  return 0
}

gen3_log_info "capturing and archiving logs from failed pods (if any)..."

# image pull errors
array_of_img_pull_errors=($(g3kubectl get pods | grep -E "ErrImagePull|ImagePullBackOff" | xargs -I {} echo {} | awk '{ print $1 }' | tr "\n" " "))
  
for pod in "${array_of_img_pull_errors[@]}"; do
  pod_name=$(echo $pod | xargs)
  gen3_log_info "storing kubectl describe output into k8s_reset_${pod_name}.log..."
  g3kubectl describe pod $pod_name > img_pull_error_${pod_name}.log
done

# container / service startup errors
array_of_svc_startup_errors=($(g3kubectl get pods | grep -E "Failed|CrashLoopBackOff" | xargs -I {} echo {} | awk '{ print $1 }' | tr "\n" " "))

for pod in "${array_of_svc_startup_errors[@]}"; do
  pod_name=$(echo $pod | xargs)
  gen3_log_info "storing kubectl logs output into svc_startup_error_${pod_name}.log..."
  container_name=$(g3kubectl get pod ${pod_name} -o jsonpath='{.spec.containers[0].name}')
  g3kubectl logs $pod_name -c ${container_name} > svc_startup_error_${pod_name}.log
done

echo "$(date): Done capturing logs" > save-failed-pod-logs.log
