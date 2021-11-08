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
array_of_img_pull_errors=($(g3kubectl get pods | grep -E "ErrImagePull|ImagePullBackOff|CreateContainerConfigError" | xargs -I {} echo {} | awk '{ print $1 }' | tr "\n" " "))

gen3_log_info "looking for pods with ErrImagePull, ImagePullBackOff or CreateContainerConfigError..."

for pod in "${array_of_img_pull_errors[@]}"; do
  pod_name=$(echo $pod | xargs)
  gen3_log_info "storing kubectl describe output into k8s_reset_${pod_name}.log..."
  g3kubectl describe pod $pod_name > img_pull_error_${pod_name}.log
done

# container / service startup errors
array_of_svc_startup_errors=($(g3kubectl get pods | grep -E "Failed|CrashLoopBackOff|Evicted" | xargs -I {} echo {} | awk '{ print $1 }' | tr "\n" " "))

gen3_log_info "looking for pods in Failed, CrashLoopBackOff of Evicted state..."

for pod in "${array_of_svc_startup_errors[@]}"; do
  pod_name=$(echo $pod | xargs)
  gen3_log_info "storing kubectl logs output into svc_startup_error_${pod_name}.log..."
  container_name=$(g3kubectl get pod ${pod_name} -o jsonpath='{.spec.containers[0].name}')
  g3kubectl logs $pod_name -c ${container_name} > svc_startup_error_${pod_name}.log
  g3kubectl describe pod $pod_name > describe_pod_${pod_name}.log
  gen3_log_info "capturing kube events..."
  g3kubectl get events --sort-by=.metadata.creationTimestamp > kubectl_get_events.log
done

gen3_log_info "looking for pods with restarting containers..."

# get array of pods
array_of_pods=( $(g3kubectl get pods | tail -n +2 | xargs -I {} echo {} | awk '{ print $1 }' | tr "\n" " ") )

for pod in "${array_of_pods[@]}"; do
  # trim whitespaces
  pod_name=$(echo $pod | xargs)
  # check if the restartCount is greater than zero
  # e.g., g3kubectl get pod metadata-deployment-5b897b7cfd-s2kmt -o jsonpath='{.status.containerStatuses[0].restartCount}'
  restart_count=$(g3kubectl get pod ${pod_name} -o jsonpath='{.status.containerStatuses[0].restartCount}')

  gen3_log_info "pod: ${pod_name} - restartCount: ${restart_count}"

  if [[ $restart_count -gt 0 ]]; then
    gen3_log_info "Pod $pod_name restarted $restart_count times... let us capture some logs."
    # grabbing list of all containers and initContainers
    # and then save all the logs
    container_names=$(g3kubectl get pod ${pod_name} -o jsonpath='{.spec.containers[*].name} {.spec.initContainers[*].name}')
    for container_name in $container_names; do
      gen3_log_info "Saving log for ${container_name}"
      g3kubectl logs $pod_name -c ${container_name} | tail -n10
      # TODO: this is not being archived by pipelineHelper.teardown for some reason :/
      g3kubectl logs $pod_name -c ${container_name} > svc_startup_error_${pod_name}_${container_name}.log
      g3kubectl describe pod $pod_name > describe_pod_${pod_name}.log
      realpath svc_startup_error_${pod_name}.log
    done
  fi
done

echo "$(date): Done capturing logs" > save-failed-pod-logs.log
