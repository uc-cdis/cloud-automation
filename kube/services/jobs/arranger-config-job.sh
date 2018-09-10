#
# Helper script for arranger-config-job.yaml
# Tar's up given folder full of arranger-config info
# collected via elasticdump:
#    https://github.com/taskrabbit/elasticsearch-dump
#    https://github.com/uc-cdis/gen3-arranger/blob/master/Docker/Stacks/esearch/indexSetup.sh#L82
#

folder="$1"

if [[ -z "$folder" || ! -d "$folder" ]]; then
  echo "ERROR: folder does not exist: $folder"
  echo "Use: bash arranger-config-job.sh folder"
  exit 1
fi

# Make sure the folder has some json files
if ! ls "$folder/" | grep '__.*.json$' > /dev/null 2>&1; then
  echo "ERROR: $folder does not seem to include elasticdump export files ...__data.json or ...__mapping.json"
  exit 1
fi

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

tdir=$(mktemp -d "${XDG_RUNTIME_DIR}/arrangerJob.XXXXXX")
cp -r "$folder" "${tdir}/arrangerConfig"
tar -C "${tdir}" -cvJf "${tdir}/arrangerConfig.tar" arrangerConfig

gen3 update_config arranger-config "${tdir}/arrangerConfig.tar"
