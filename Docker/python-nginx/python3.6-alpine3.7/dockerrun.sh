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
GEN3_DRYRUN="${GEN3_DRYRUN:-False}"
GEN3_UWSGI_TIMEOUT="${GEN3_UWSGI_TIMEOUT:-45s}"

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
  dockkerrun.bash [--help] [--debug=False] [--uwsgiTimeout=45s] [--dryrun=False]
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
  uwsgiTimeout)
    GEN3_UWSGI_TIMEOUT="${value:-45s}"
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
GEN3_UWSGI_TIMEOUT=$GEN3_UWSGI_TIMEOUT
GEN3_DRYRUN=$GEN3_DRYRUN
EOM

run update-ca-certificates
run mkdir -p /var/run/gen3

# fill in timeout in the uwsgi.conf template
if [ -f /etc/nginx/sites-available/uwsgi.conf ]; then
  sed -i -e "s/GEN3_UWSGI_TIMEOUT/$GEN3_UWSGI_TIMEOUT/g" /etc/nginx/sites-available/uwsgi.conf
fi

#
# Enable debug flag based on GEN3_DEBUG environment
#
if [ -f ./wsgi.py ] && [ "$GEN3_DEBUG" = "True" ]; then
  echo -e "\napplication.debug=True\n" >> ./wsgi.py
fi

(
  run uwsgi --ini /etc/uwsgi/uwsgi.ini
) &

if [[ $GEN3_DRYRUN == "False" ]]; then
  (
    while true; do
      logrotate --force /etc/logrotate.d/nginx
      sleep 86400
    done
  ) &
fi

if [[ $GEN3_DRYRUN == "False" ]]; then
  (
    while true; do
      curl -s http://127.0.0.1:9117/metrics > /var/www/metrics/metrics.txt
      curl -s http://127.0.0.1:9113/metrics >> /var/www/metrics/metrics.txt
      curl -s http://127.0.0.1:4040/metrics >> /var/www/metrics/metrics.txt
      sleep 10
    done
  ) &
fi

run nginx -g 'daemon off;'
wait
