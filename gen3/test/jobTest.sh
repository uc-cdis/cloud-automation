
#
# @param jobKey path or key
# @return 0 if the job should be excluded from integrity tests
#
excludeJob() {
  local jobKey="$1"
  local excludeList=(
    /aws-bucket- /bucket- /covid19- /data-ingestion- /google- /nb-etl- /remove-objects-from- /replicate- /s3sync- /fence-cleanup /etl- /indexd- /metadata-
  )
  for exclude in "${excludeList[@]}"; do
    if [[ "$it" =~ $exclude ]]; then return 0; fi
  done
  return 1
}

test_job_json() {
  local it
  for it in "$GEN3_HOME"/kube/services/jobs/*job.yaml; do
    if excludeJob "$it"; then continue; fi
    gen3 job json "$it" > /dev/null; because $? "job json ran ok with: $it"
  done
}

test_job_cronjson() {
  local it
  for it in "$GEN3_HOME"/kube/services/jobs/*-job.yaml; do
    if excludeJob "$it"; then continue; fi
    gen3 job cron-json "$it" "@daily" > /dev/null; because $? "job cron-json ran ok with: $it"
  done
}

test_job_envtest() {
  gen3 job run envtest -w; because $? "job run envtest should work"
  gen3 job logs envtest > /dev/null; because $? "job logs envtest should work"
}


shunit_runtest "test_job_json" "job"
shunit_runtest "test_job_cronjson" "job"
shunit_runtest "test_job_envtest" "job"
