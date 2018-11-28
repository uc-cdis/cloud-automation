#!/bin/sh
#
# Note: base nginx-alpine does not include bash shell

#
# Gen3 sidecar
# * SSL/TLS
# * JSON access logging
# * uwsgi proxy
#
# TODO
# * rate limiting and circuite breakers
# * reject secure routes with invalid JWT
# * forward and reverse proxy for service discovery and testing and tracing
#

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"

GEN3_DEBUG="${GEN3_DEBUG:-False}"
GEN3_UWSGI="${GEN3_UWSGI:-True}"
GEN3_UWSGI_ROUTE="${GEN3_UWSGI_ROUTE:-/}"
GEN3_UWSGI_TIMEOUT="${GEN3_UWSGI_TIMEOUT:-45s}"
GEN3_DRYRUN="${GEN3_DRYRUN:-False}"
GEN3_SIDECAR="${GEN3_SIDECAR:-True}"

help() {
    cat - <<EOM
Gen3 sidecar launch script
Use: 
  dockkerrun.sh [--help] [--uwsgi=True] [--uwsgiRoute=/] [--uwsgiTimeout=45s] [--dryrun=False] [--sidecar=True]

Note:
  The uwsgi configurations assumes that nginx communicates with uwsgi via /var/run/gen3/uwsgi.sock
EOM
}

run() {
  if [ "$GEN3_DRYRUN" != False ]; then
    echo "DRY RUN - not running: $@"
  else
    echo "Running $@"
    "$@"
  fi
}

#
# Copied from cloud-automation/gen3/lib/g3m_manifest.sh
# Take a templatePath, then a k1, v1, k2, v2, ... arguments,
# and process the template path replacing k1 with v1, etc
# Cats the result to stdout
#
# @param templatePath
# @param k1
# @param v1
# ...
#
g3k_kv_filter() {
  local templatePath=$1
  shift
  local key
  local value

  if [[ ! -f "$templatePath" ]]; then
    echo -e "ERROR: kv template does not exist: $templatePath" 1>&2
    return 1
  fi
  local tempFile="$XDG_RUNTIME_DIR/g3k_manifest_filter_$$"
  cp "$templatePath" "$tempFile"
  while [[ $# -gt 0 ]]; do
    key="$1"
    shift
    value="$1"
    shift || true
    #
    # this won't work if key or value contain ^ :-(
    # echo "Replace $key - $value" 1>&2
    # introduce support for default value - KEY|DEFAULT|
    # Note: -E == extended regex
    #
    sed -E -i.bak "s^${key}([|]-.+-[|])?^${value}^g" "$tempFile"
  done
  #
  # Finally - any put default values in place for any undefined variables
  # Note: -E == extended regex
  #
  sed -E -i.bak 's^[a-zA-Z][a-zA-Z0-9_-]+[|]-(.*)-[|]^\1^g' "$tempFile"
  cat $tempFile
  /bin/rm "$tempFile"
  return 0
}



while [ $# -gt 0 ]; do
  arg="$1"
  shift
  key=""
  value=""
  key="$(echo "$arg" | sed -e 's/^-*//' | sed -e 's/=.*$//')"
  value="$(echo "$arg" | sed -e 's/^.*=//')"

  if [ "$value" = "$arg" ]; then # =value not given, so use default
    value=""
  fi
  case "$key" in
  debug)
    GEN3_DEBUG="${value:-True}"
    ;;
  uwsgi)
    GEWN3_UWSGI="${value:-True}"
    ;;
  uwsgiRoute)
    GEN3_UWSGI_ROUTE="${value:-/}"
    ;;
  uwsgiTimeout)
    GEN3_UWSGI_TIMEOUT="${value:-45s}"
    ;;
  dryrun)
    GEN3_DRYRUN="${value:-True}"
    ;;
  sidecar)
    GEN3_SIDECAR="${value:-True}"
    ;;
  help)
    help
    exit 0
    ;;
  *)
    echo "ERROR: unknown argument $arg - bailing out"
    exit 1
    ;;
  esac
done

cat - <<EOM
Got configuration:
GEN3_UWSGI=$GEN3_UWSGI
GEN3_UWSGI_ROUTE=$GEN3_UWSGI_ROUTE
GEN3_UWSGI_TIMEOUT=$GEN3_UWSGI_TIMEOUT
GEN3_DRYRUN=$GEN3_DRYRUN
GEN3_SIDECAR=$GEN3_SIDECAR
EOM

if [ "$GEN3_UWSGI" != True ]; then
  echo "ERROR: uwsgi not enabled, but that's all we do :shrug:"
  exit 1
fi

filterSource=/etc/nginx/gen3.conf.d/uwsgi.conf.template
# For local testing:
if [ ! -f "$filterSource" ] && [ -f ./uwsgi.conf.template ] && [ "$GEN3_DRYRUN" != False ]; then
  echo 'Setting local filterSource for testing ...'
  filterSource="./uwsgi.conf.template"
fi
filterTarget="$(mktemp "${XDG_RUNTIME_DIR}/uwsgi.conf_XXXXXX")"
g3k_kv_filter "${filterSource}" \
    GEN3_UWSGI_ROUTE "$GEN3_UWSGI_ROUTE" \
    GEN3_UWSGI_TIMEOUT "$GEN3_UWSGI_TIMEOUT" | tee "$filterTarget"

run cp "$filterTarget" /etc/nginx/gen3.conf.d/uwsgi.conf
rm "$filterTarget"

if [ "$GEN3_SIDECAR" = True ]; then
  run nginx -g 'daemon off;'
else
  while true; do
    echo "sidecar disabled - just running sleep loop"
    sleep 60
  done
fi
