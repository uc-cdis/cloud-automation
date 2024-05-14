#!/bin/bash
#
# Deploy fence into existing commons - assume configs are already configured
# for fence to re-use the userapi db.
# This fragment is pasted into kube-services.sh by kube.tf.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

setup_audit_sqs() {
  local sqsName="audit-sqs"
  sqsInfo="$(gen3 sqs create-queue-if-not-exist $sqsName)" || exit 1
  sqsUrl="$(jq -e -r '.["url"]' <<< "$sqsInfo")" || { echo "Cannot get 'sqs-url' from output: $sqsInfo"; exit 1; }
  sqsArn="$(jq -e -r '.["arn"]' <<< "$sqsInfo")" || { echo "Cannot get 'sqs-arn' from output: $sqsInfo"; exit 1; }

  # fence can push messages to the audit queue
  local saName="fence-sa"
  local roleName="$(gen3 api safe-name audit-sqs-sender)" || exit 1
  gen3_log_info "setting up service account '$saName' with role '${roleName}'"
  if ! gen3 awsrole info "$roleName" > /dev/null; then # create role
    gen3 awsrole create "$roleName" "$saName" || exit 1
  fi
  gen3 sqs attach-sender-policy-to-role $sqsArn $roleName || exit 1
}

gen3 update_config fence-yaml-merge "${GEN3_HOME}/apis_configs/yaml_merge.py"
[[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets

if [[ -f "$(gen3_secrets_folder)/creds.json" && -z "$JENKINS_HOME" ]]; then # create database
  # Initialize fence database and user list
  cd "$(gen3_secrets_folder)"
  if [[ ! -f .rendered_fence_db ]]; then
    gen3 job run fencedb-create
    gen3_log_info "Waiting 10 seconds for fencedb-create job"
    sleep 10
    gen3 job logs fencedb-create || true
    gen3 job run useryaml
    gen3 job logs useryaml || true
    gen3_log_info "Leaving setup jobs running in background"
  fi
  # avoid doing the previous block more than once or when not necessary ...
  touch "$(gen3_secrets_folder)/.rendered_fence_db"
fi

g3kubectl create sa "fence-sa" > /dev/null 2>&1 || true

if ! [[ -n "$JENKINS_HOME" || ! -f "$(gen3_secrets_folder)/creds.json" ]]; then
  if ! setup_audit_sqs; then
    gen3_log_err "kube-setup-fence bailing out - failed to setup audit SQS"
    exit 1
  fi
fi

# run db migration job - disable, because this still causes locking in dcf
if false; then
  gen3_log_info "Launching db migrate job"
  gen3 job run fence-db-migrate -w || true
  gen3 job logs fence-db-migrate -f || true
fi

# deploy fence
gen3 roll fence
g3kubectl apply -f "${GEN3_HOME}/kube/services/fence/fence-service.yaml"

portalApp="$(g3k_manifest_lookup .global.portal_app)"
if ! [[ "$portalApp" =~ ^GEN3-WORKSPACE ]]; then
  # deploy presigned-url-fence
  gen3 roll presigned-url-fence
  g3kubectl apply -f "${GEN3_HOME}/kube/services/presigned-url-fence/presigned-url-fence-service.yaml"
fi

gen3 roll fence-canary || true
g3kubectl apply -f "${GEN3_HOME}/kube/services/fence/fence-canary-service.yaml"
gen3_log_info "The fence service has been deployed onto the k8s cluster."

gen3 kube-setup-google

# add cronjob for removing expired ga4gh info for required fence versions
if isServiceVersionGreaterOrEqual "fence" "6.0.0" "2022.07"; then
  # Setup db cleanup cronjob
  if ! g3kubectl get cronjob fence-cleanup-expired-ga4gh-info >/dev/null 2>&1; then
      echo "fence-cleanup-expired-ga4gh-info being added as a cronjob b/c fence >= 6.0.0 or 2022.07"
      gen3 job cron fence-cleanup-expired-ga4gh-info "*/5 * * * *"
  fi

  # Extract the value of ENABLE_VISA_UPDATE_CRON from the configmap manifest-fence (fence-config-public.yaml)
  ENABLE_VISA_UPDATE_CRON=$(kubectl get cm manifest-fence -o=jsonpath='{.data.fence-config-public\.yaml}' | yq -r .ENABLE_VISA_UPDATE_CRON)

  # Delete the fence-visa-update cronjob if ENABLE_VISA_UPDATE_CRON is set to false or not set or null  in the configmap manifest-fence
  if [[ "$ENABLE_VISA_UPDATE_CRON" == "false" ]] || [[ "$ENABLE_VISA_UPDATE_CRON" == "null" ]] || [[ -z "$ENABLE_VISA_UPDATE_CRON" ]]; then
      echo "Deleting fence-visa-update cronjob"
      kubectl delete cronjob fence-visa-update
  elif [[ "$ENABLE_VISA_UPDATE_CRON" == "true" ]]; then
      if ! g3kubectl get cronjob fence-visa-update >/dev/null 2>&1; then
          echo "fence-visa-update being added as a cronjob b/c fence >= 6.0.0 or 2022.07"
          gen3 job cron fence-visa-update "30 * * * *"
      fi
  else
      echo "ENABLE_VISA_UPDATE_CRON has an unexpected value in the configmap manifest-fence. Skipping fence-visa-update cronjob setup."
  fi
fi

# add cronjob for removing expired OIDC clients for required fence versions
if isServiceVersionGreaterOrEqual "fence" "6.2.0" "2023.01"; then
  if ! g3kubectl get cronjob fence-delete-expired-clients >/dev/null 2>&1; then
      echo "fence-delete-expired-clients being added as a cronjob b/c fence >= 6.2.0 or 2023.01"
      gen3 job cron fence-delete-expired-clients "0 7 * * *"
  fi
fi
