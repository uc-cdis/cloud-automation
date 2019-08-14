source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


s3LogsReport() {
  local s3Path
  local minDate
  local maxDate
}


bhcReport() {
  local logFolders
  local inputName
  local outputName
  
  # 
  logFolders=(
    s3://bhc-bucket-logs # / - for bhc-data
    s3://bhcprodv2-data-bucket-logs/log/
    s3://s3logs-s3logs-mjff-databucket-gen3/log/
  )
  lsFiles=(

  )

  for inputName in "${logFolders[@]}"; do 
      echo $inputName; outputName="${inputName#s3://}";
      outputName="ls.${outputName%%/*}.txt"; 
      echo $outputName; 
      aws s3 ls "$inputName" | tee "${outputName}"
      echo -------;
      lsFiles+=($outputName) 
  done
  for inputName in ls.*.txt; do
      outputName="${inputName//ls./2019.}"
      echo "$outputName"
      cat "$inputName" | awk '{ print $4 }' | grep -E '2019-0[678]-' | tee "$outputName"
      echo ---------
  done
  rm tempfile 2> /dev/null || true
  for inputName in 2019.*.txt; do
      bucketName="${inputName#2019.}"
      bucketName="${bucketName%.txt}"
      outputName="raw.${bucketName}.txt"
      prefix="/log"
      if [[ "$bucketName" == bhc-bucket-logs ]]; then
        prefix=""
      fi
      echo "$outputName gets s3://$bucketName$prefix/"
      cat "$inputName" | while read -r path; do 
        fullPath="s3://$bucketName$prefix/$path"
        echo "Downloading $fullPath"
        if aws s3 cp "$fullPath" tempfile; then
          cat tempfile >> "$outputName"
          rm tempfile
        else
          echo "Failed to download $fullPath"
          rm tempfile 2> /dev/null || true
        fi
      done
      echo ---------
    done
    for inputName in raw.*.txt; do
      bucketName="${inputName#raw.}"
      bucketName="${bucketName%.txt}"
      outputName="ips.${bucketName}.txt"
      echo "Scanning $inputName for $outputName"
      cat "$inputName" | awk '{ print $5 " " $8 " " $13 }' | grep GET.OBJECT | grep 200 | awk '{ print $1 }' | sort -u | tee "$outputName"
    done
}

