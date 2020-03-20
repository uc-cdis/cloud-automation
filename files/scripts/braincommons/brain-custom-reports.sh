#
# Generate S3 access and Dream-challenger user login reports for 
# the brain commons, and publish to dashboard service
#
# Run as cron:
# GEN3_HOME=/home/bhcprodv2/cloud-automation
# PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# 2   2   *   *   1    (if [ -f $GEN3_HOME/files/scripts/braincommons/brain-custom-reports.sh ]; then bash $GEN3_HOME/files/scripts/braincommons/brain-custom-reports.sh go; else echo "no brain-custom-reports.sh"; fi) > $HOME/brain-custom-reports.log 2>&1


source "${GEN3_HOME}/gen3/gen3setup.sh"


# lib -------------------------

BEATPD="${GEN3_HOME}/files/scripts/braincommons/beatpd-files.txt"
beatpdFilter() {
  while read -r LINE; do
    local path
    if path="$(awk '{ print $2 }' <<<"$LINE")" && grep "$path" "$BEATPD" > /dev/null 2>&1; then
      echo -e "$LINE"
    else
      gen3_log_info "SKIPPING $LINE - not in beatpd"
    fi
  done
}

# main ------------------------

# pin start date to January 13
startDate="2020-01-13"
numDays=0

if [[ $# -lt 1 || "$1" != "go" ]]; then
  gen3_log_err "Use: brain-custom-reports.sh go"
  exit 1
fi
shift

#startDate="$1"
startSecs="$(date -u -d"$startDate" +%s)"
endSecs="$(date -u -d"00:00" +%s)"
numDays="$(( (endSecs - startSecs)/(24*60*60) ))"
gen3_log_info "$numDays days since $startDate"

dropDeadSecs="$(date -u -d2020-05-01 +%s)"
if [[ "$endSecs" -gt "$dropDeadSecs" ]]; then
  gen3_log_err "This script will not process logs after 2020-05-01"
  exit 1
fi

# to simplify testing - optionally take an already existing workfolder
if [[ $# -gt 0 && -f "$1/raw.txt" ]]; then
  workFolder="$1"
  shift
  folderName="$(basename "$workFolder")"
else
  folderName="$(date -d"$numDays days ago" -u +%Y%m%d)-$(date -u +%Y%m%d_%H%M%S)"
  workFolder="$(mktemp -d -p "$XDG_RUNTIME_DIR" brainCustomReport_XXXXXX)/$folderName"
fi
mkdir -p "$workFolder"
cd "$workFolder"
gen3_log_info "working in $workFolder"

# cache raw data from last run, and add to it incrementally
cacheDate="2020-03-05"
cacheFile="${XDG_DATA_HOME}/gen3/cache/brain-custom-report_2020-01-13_to_2020-03-05_raw.txt"
if [[ ! -f "$cacheFile" ]]; then
  gen3_log_err "Please generate cache $cacheFile : gen3 logs s3 start=2020-01-13 end=2020-03-05 filter=raw prefix=s3://bhcprodv2-data-bucket-logs/log/bhcprodv2-data-bucket/ > brain-custom-report_2020-01-13_to_2020-03-05_raw.txt"
  exit 1
fi

if [[ -f raw.txt ]]; then
  gen3_log_info "using existing raw.txt - probably testing something"
else
  gen3 logs s3 start="$cacheDate 00:00" end="00:00" filter=raw prefix=s3://bhcprodv2-data-bucket-logs/log/bhcprodv2-data-bucket/ > "raw-${cacheDate}.txt"
  cat "$cacheFile" "raw-${cacheDate}.txt" > "raw.txt"
fi
gen3 logs s3filter filter=accessCount < raw.txt > accessCountRaw.tsv
gen3 logs s3filter filter=whoWhatWhen < raw.txt > whoWhatWhenRaw.tsv 

if dreamReport="$(bash "${GEN3_HOME}/files/scripts/braincommons/dream-access-report-cronjob.sh" "$numDays" | tail -1)" && [[ -f "$dreamReport" ]]; then
  gen3_log_info "cp $dreamReport to $workFolder/dream_access_report.tsv"
  cp "$dreamReport" dream_access_report.tsv
else
  gen3_log_err "Failed to generate Dream access report"
fi  

# Some customization for the brain-commons beat-pd dream challenge case
echo -e "Access_count\tdid\tfilename" > DREAM_Download_Summary.tsv
grep dg.7519/ accessCountRaw.tsv | beatpdFilter | sed -E 's@(dg.7519/.+)/(.+)@\1\t\2@' | tee -a DREAM_Download_Summary.tsv

echo -e "Date_time\tdid\tfilename\tUser_id" > DREAM_Download_Details.tsv
grep dg.7519/ whoWhatWhenRaw.tsv | beatpdFilter | sed -E 's@(dg.7519/.+)/(.+)@\1\t\2@' | sed 's/__Synapse_ID_/ (Synapse ID)/g' >> DREAM_Download_Details.tsv

if [[ -d "$workFolder" ]]; then
  gen3 dashboard publish secure "$workFolder" "dreamAccess/$(date -u +%Y)/$folderName"
  cd "$XDG_RUNTIME_DIR"
  gen3_log_info "cleaning up $workFolder"
  /bin/rm -rf "$workFolder"
fi
