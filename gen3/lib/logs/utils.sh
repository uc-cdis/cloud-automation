LOGHOST="${LOGHOST:-https://kibana.planx-pla.net}"
LOGUSER="${LOGUSER:-kibanaadmin}"
LOGPASSWORD="${LOGPASSWORD:-"deprecated"}"


#
# Little wrapper around curl that always passes '-s', '-u user:password', '-H Content-Tpe application/json',
# plus other args passed as inputs
#
# @param path under $LOGHOST/ to curl
# @param ... other curl args
#
gen3_logs_curl() {
  local path
  local fullPath
  local ctype

  if [[ $# -gt 0 ]]; then
    path="$1"
    shift
  else
    path="_cat/indices"
  fi
  if [[ "$path" =~ ^https?:// ]]; then
    fullPath="$path"
  else
    fullPath="$LOGHOST/$path"
  fi
  ctype="application/json"
  if [[ "$path" =~ /_bulk$ ]]; then
    # ES /_bulk API wants application/ndjson ... 
    ctype="application/ndjson"
  fi
  gen3_log_info "gen3_logs_curl" "$fullPath"
  curl -s -u "${LOGUSER}:${LOGPASSWORD}" -H "Content-Type: $ctype" "$fullPath" "$@"
}


#
# Same as gen3_logs_curl, but passes -i, -H Content-Type, and fails if  HTTP result is not 200 - sending output to stderr.
# This can be a little tricky - behind proxy curl -i gives status of proxy connection - ex:
# """
# HTTP/1.1 200 Connection established
#
# HTTP/1.1 200 OK
# Date: Tue, 12 Mar 2019 19:07:46 GMT
# ...
# """
# Also - content-type is set to application/ndjson if endpoint matches /_bulk - see
#     https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-bulk.html
#
gen3_logs_curl200() {
  local tempFile
  local result
  local path
  local httpStatus
  tempFile="$(mktemp "$XDG_RUNTIME_DIR/curl.json_XXXXXX")"
  result=0
  path="$1"
  if ! gen3_logs_curl "$@" -i > "$tempFile"; then
    gen3_log_err "gen3_logs_curl200" "non-zero exit from curl $path"
    cat "$tempFile" 1>&2
    result=1
  elif httpStatus="$(awk -f "$GEN3_HOME/gen3/lib/curl200Status.awk" < "$tempFile")" && [[ "$httpStatus" == 200  || "$httpStatus" == 201 ]]; then
    # looks like HTTP/.. 200!
    # curl200Body.awk outputs the body of the curl -i response
    # curl200Status.awk outputs the HTTP status of the curl -i response
    awk -f "$GEN3_HOME/gen3/lib/curl200Body.awk" < "$tempFile"
    result=0
  else
    gen3_log_err "gen3_logs_curl200" "non-200 from curl $path"
    cat "$tempFile" 1>&2
    result=1
  fi
  rm "$tempFile"
  return $result      
}

#
# Same as gen3_logs_curl200, but passes the output through 'jq -e -r .'
# to verify, and returns that exit code.  On failure sends output to stderr instead of stdout
#
gen3_logs_curljson() {
  local tempFile
  local result
  local path
  tempFile="$(mktemp "$XDG_RUNTIME_DIR/curl.json_XXXXXX")"
  result=0
  path="$1"
  if ! gen3_logs_curl200 "$@" > "$tempFile"; then
    result=1
  elif jq -e -r . < "$tempFile" > /dev/null 2>&1; then
    cat "$tempFile"
    result=0
  else
    result=1
    gen3_log_err "gen3_logs_curljson" "non json output from $path"
    cat "$tempFile" 1>&2
  fi
  rm "$tempFile"
  return $result
}

gen3LogsVpcList=(
    "accountprod  acct.bionimbus.org"
    "anvilprod theanvil.io"
    "anvilstaging staging.theavil.io"
    "bloodv2 data.bloodpac.org"
    "bhcprodv2 data.braincommons.org"
    "canineprod caninedc.org"
    "covid19prod chicagoland.pandemicresponsecommons.org"
    "dataguids dataguids.org"
    "dcfqav1 qa.dcf.planx-pla.net"
    "dcfprod nci-crdc.datacommons.io"
    "dcf-staging nci-crdc-staging.datacommons.io"
    "devplanetv1 dev.planx-pla.net"
    "edcprodv2 portal.occ-data.org environmental data commons"
    "genomelprod genomel.bionimbus.org"
    "gtexprod dcp.bionimbus.org"
    "kfqa dcf-interop.kidsfirstdrc.org"
    "ibdgc-prod ibdgc.datacommons.io"
    "loginbionimbus login.bionimbus.org"
    "ncicrdcdemo nci-crdc-demo.datacommons.io"
    "niaiddata niaiddata.org"
    "niaidprod niaid.bionimbus.org"
    "oadc gen3.datacommons.io"  
    "prodv1 data.kidsfirstdrc.org kids first"
    "skfqa gen3qa.kidsfirstdrc.org kids first"
    "qaplanetv1 qa.planx-pla.net jenkins"
    "stageprod gen3.datastage.io"
    "stagingdatastage staging.datastage.io"
    "vadcprod vpodc.org"
    "vhdcprod va.datacommons.io"
)

#
# Dump vpclist
# The output lists one vpc per line where
# the first two tokens of each line are the
# `vpcName` and one `hostname` associated with
# a commons running in that vpc:
# ```
# vpcName hostname other descriptive stuff to grep on
# ```
#
gen3_logs_vpc_list() {
  local info
  for info in "${gen3LogsVpcList[@]}"; do
    echo "$info"
  done
}

#
# Little helper - first argument is key,
# remaining arguments are of form "key=value" to search through for that key
# @param key
# @param defaultValue echo $default if not key not found
# @return echo the value extracted from remaining arguments or "" if not found
#
gen3_logs_get_arg() {
  if [[ $# -lt 2 || -z "$1" || "$1" =~ /=/ ]]; then
    gen3_log_err "gen3_logs_get_arg" "no valid key to gen3_logs_get_arg"
    echo ""
    return 1
  fi
  local key
  local entry
  local defaultValue
  key="$1"
  shift
  defaultValue="$1"
  shift
  for entry in "$@"; do
    if [[ "$entry" =~ ^${key}= ]]; then
      echo "$entry" | sed "s/^${key}=//"
      return 0
    fi
  done
  echo "$defaultValue"
  return 1
}

gen3_logs_fix_date() {
  local dt
  dt="$1"
  date --utc --date "$dt" '+%Y/%m/%d %H:%M'
}

gen3_logs_user_list() {
  echo "SELECT 'uid:'||id,email FROM \"User\" WHERE email IS NOT NULL;" | gen3 psql fence --no-align --tuples-only --pset=fieldsep=,
}
