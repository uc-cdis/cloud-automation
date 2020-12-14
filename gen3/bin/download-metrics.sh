#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

# lib -----------------------------------

gen3_download_metrics_help() {
  gen3 help download-metrics
}

gen3_download_metrics_task() {
  cat $XDG_RUNTIME_DIR/RESULT | grep "$1" | grep "protocol=$2" >> $XDG_RUNTIME_DIR/TEMPRESULT
}

gen3_download_metrics() {
  dateTime="$(date --date 'yesterday 00:00' +%Y%m%d)"
  destFolder="reports/$(date --date 'yesterday 00:00' +%Y)/$(date --date 'yesterday 00:00' +%m)"
  local date
  local user
  gen3 logs raw vpc=$vpc proxy=presigned-url-fence statusmin=199 statusmax=210 | grep /data/download | jq -r . > $XDG_RUNTIME_DIR/DOWNLOADS
  if [[ -z $preserveUsernames ]]; then
    cat $XDG_RUNTIME_DIR/DOWNLOADS | jq -r .http_request > $XDG_RUNTIME_DIR/RESULT
  else
    cat $XDG_RUNTIME_DIR/DOWNLOADS | jq -r '. | "\(.user_id) \(.http_request)"' > $XDG_RUNTIME_DIR/RESULT
  fi
  # Check for downloads from a specific bucket
  if [[ ! -z  $bucketName ]]; then
     gen3 psql indexd -c "select did from index_record_url where url like '$bucketType://$bucketName/%';" >> $XDG_RUNTIME_DIR/GUIDS
    while read line; do
      ((i=i%5)); ((i++==0)) && wait
      gen3_download_metrics_task "$line" "$bucketType" &
    done<$XDG_RUNTIME_DIR/GUIDS
    mv $XDG_RUNTIME_DIR/TEMPRESULT $XDG_RUNTIME_DIR/RESULT
  fi
  cat  $XDG_RUNTIME_DIR/RESULT | sort | uniq --count | sed 's/^ *//'  >  $XDG_RUNTIME_DIR/COUNTS

  if [[ ! -z $preserveUsernames ]]; then
   csvToJson="$(cat - <<EOM
BEGIN {
  prefix="";
  print "{ \"data\": [";
};

(\$0 ~ /,/) {
  print prefix "[\"" \$1 "\",\"" \$3 "\"," \$2 "]"; prefix=","};
END {
  print "] }"
};
EOM
    )"
   cat $XDG_RUNTIME_DIR/COUNTS | sed -r 's/ /,/g' |  awk -F, '{$0=$3","$1","$4}1' | awk -F , "$csvToJson" | jq -r . | tee "downloads-${dateTime}.json"
  else
    csvToJson="$(cat - <<EOM
BEGIN {
  prefix="";
  print "{ \"data\": [";
};

(\$0 ~ /,/) {
  print prefix "[\"" \$1 "\"," \$2 "]"; prefix=","
};

END {
  print "] }"
};
EOM
    )"
    cat $XDG_RUNTIME_DIR/COUNTS | sed -r 's/ /,/g' |  awk -F, '{$0=$2","$1}1' | awk -F , "$csvToJson" | jq -r . | tee "downloads-${dateTime}.json"
  fi
  if [[ ! -z $publishDashboard ]]; then
    local destFolder="reports/$(date --date 'yesterday 00:00' +%Y)/$(date --date 'yesterday 00:00' +%m)"
    gen3 dashboard publish secure "downloads-${dateTime}.json" "${destFolder}/downloads-${dateTime}.json"
  fi
}



OPTIND=1
OPTSPEC=":-:"
while getopts "$OPTSPEC" optchar; do
  case "${optchar}" in
    -)
      case "${OPTARG}" in
        vpc=*)
          vpc=${OPTARG#*=}
          ;;
        vpc)
          vpc="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          ;;
        bucket-name=*)
          bucketName=${OPTARG#*=}
          ;;
        bucket-name)
          bucketName="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          ;;
        bucket-type=*)
          bucketType=${OPTARG#*=}
          ;;
        bucket-type)
          bucketType="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          ;;
        preserve-usernames=*)
          preserveUsernames=${OPTARG#*=}
          ;;
        preserve-usernames)
          preserveUsernames="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          ;;
        publish-dashboard=*)
          publishDashboard=${OPTARG#*=}
          ;;
        publish-dashboard)
          publishDashboard="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          ;;
        help)
          gen3_download_metrics_help
          exit
          ;;
        *)
          if [ "$OPTERR" = 1 ] && [ "${OPTSPEC:0:1}" != ":" ]; then
            echo "Unknown option --${OPTARG}" >&2
            gen3_download_metrics_help
            exit 2
          fi
          ;;
      esac;;
    *)
      if [ "$OPTERR" != 1 ] || [ "${OPTSPEC:0:1}" = ":" ]; then
        echo "Non-option argument: '-${OPTARG}'" >&2
        gen3_download_metrics_help
        exit 2
      fi
      ;;
    esac
done

# Stop if required params are not set
if [[ -z $vpc ]]; then
  gen3_replicate_help "VPC is required "
  exit 1
  else
    gen3_download_metrics
  fi
exit $?