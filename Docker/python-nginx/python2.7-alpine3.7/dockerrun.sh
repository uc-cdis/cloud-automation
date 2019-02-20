#!/bin/sh
#
# Note: base alpine Linux image may not include bash shell,
#    and we probably want to move to that for service images,
#    so just use bourn shell ...

#
# Update certificate authority index -
# environment may have mounted more authorities
# - ex: /usr/local/share/ca-certificates/cdis-ca.crt into system bundle       
#

GEN3_DEBUG="${GEN3_DEBUG:-False}"
GEN3_SIDECAR="${GEN3_SIDECAR:-False}"
GEN3_DRYRUN="${GEN3_DRYRUN:-False}"

run() {
  if [ "$GEN3_DRYRUN" = True ]; then
    echo "DRY RUN - not running: $@"
  else
    echo "Running $@"
    "$@"
  fi
}

help() {
    cat - <<EOM
Gen3 base (generic) launch script
Use: 
  dockkerrun.bash [--help] [--debug=False] [--sidecar=False] [--dryrun=False]
EOM
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
  sidecar)
    GEN3_SIDECAR="${value:-True}"
    ;;
  dryrun)
    GEN3_DRYRUN="${value:-True}"
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
GEN3_DEBUG=$GEN3_DEBUG
GEN3_SIDECAR=$GEN3_SIDECAR
GEN3_DRYRUN=$GEN3_DRYRUN
EOM

run update-ca-certificates
run mkdir -p /var/run/gen3

#
# Enable debug flag based on GEN3_DEBUG environment
#
if [ -f ./wsgi.py ] && [ "$GEN3_DEBUG" = "True" ]; then
  echo -e "\napplication.debug=True\n" >> ./wsgi.py
fi

(
  # Wait for nginx to create uwsgi.sock in a sub-process
  count=0
  while [ ! -e /var/run/gen3/uwsgi.sock ] && [ $count -lt 10 ]; do
    echo "... waiting for /var/run/gen3/uwsgi.sock to appear"
    sleep 2
    count="$(($count+1))"
  done
  if [ ! -e /var/run/gen3/uwsgi.sock ]; then
    echo "WARNING: /var/run/gen3/uwsgi.sock does not exist!!!"
  fi
  run uwsgi --ini /etc/uwsgi/uwsgi.ini
) &

if [ "${GEN3_SIDECAR}" = False ]; then
  run nginx -g 'daemon off;'
fi
wait