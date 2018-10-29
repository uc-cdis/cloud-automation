
fluentd_run() {
  mkdir -p varlogs
  mkdir -p dockerlogs
  docker run -it --rm --name reuben-fluentd --entrypoint /bin/bash --env 'FLUENTD_CONF=gen3.conf' -v "$(pwd):/gen3" -v "$(pwd)/varlogs:/var/log/containers" -v "$(pwd)/dockerlogs:/var/lib/docker/containers" "fluent/fluentd-kubernetes-daemonset:v1.2-debian-cloudwatch"
}

fluentd_log() {
  local log
  log="$(echo "$@" | sed -e 's/"/\\"/g')"
  echo '{"log": "'"$log"'"}'
}
