#!/bin/bash
#################################################################################################
# 
# NAME: fix_sa_perms.sh
# Author: Aaron Strong <astrong@burwood.com> and James Anderton <janderton@burwood.com>
# Purpose: This script will create a new service account key and reset permissions to what is required
#          for our terraforms to run correctly.
#
#################################################################################################
set -e
set -u

# check for input variables
if [ $# -lt 3 ]; then
  echo
  echo "Usage: $0 <organization name> <project id> <service account email address>"
  echo
  echo "  organization name (required)"
  echo "  project id (required)"
  echo "  service account email address (required)"
  echo
  echo
  exit 1
fi

# Organization ID
echo "Verifying organization..."
ORG_ID="$(gcloud organizations list --format="value(ID)" --filter="$1")"

if [[ $ORG_ID == "" ]];
then
  echo "The organization id provided does not exist. Exiting."
  exit 1;
fi

 # Seed Project
echo "Verifying project..."
SEED_PROJECT="$(gcloud projects list --format="value(projectId)" --filter="$2")"

if [[ $SEED_PROJECT == "" ]];
then
   echo "The Seed Project does not exist. Exiting."
  exit 1;
fi



######## Seed Service Account Info ##########################
SA_ID="$3"
STAGING_DIR="${PWD}"
KEY_FILE="${STAGING_DIR}/credentials.json"
#############################################################

echo "Downloading key to credentials.json..."
gcloud iam service-accounts keys create "${KEY_FILE}" \
    --iam-account "${SA_ID}" \
    #--user-output-enabled false

echo "Applying permissions for org $ORG_ID and project $SEED_PROJECT..."
 # Grant roles/resourcemanager.organizationViewer to the Seed Service Account on the organization
gcloud organizations add-iam-policy-binding \
  "${ORG_ID}" \
  --member="serviceAccount:${SA_ID}" \
  --role="roles/resourcemanager.organizationViewer" \
  #--user-output-enabled false

# Grant roles/resourcemanager.projectCreator to the service account on the organization
echo "Adding role roles/resourcemanager.projectCreator..."
gcloud organizations add-iam-policy-binding \
  "${ORG_ID}" \
  --member="serviceAccount:${SA_ID}" \
  --role="roles/resourcemanager.projectCreator" \
  #--user-output-enabled false

# Grant roles/orgpolicy.PolicyAdmin to the service account on the organization
echo "Adding role roles/orgpolicy.policyAdmin..."
gcloud organizations add-iam-policy-binding \
  "${ORG_ID}" \
  --member="serviceAccount:${SA_ID}" \
  --role="roles/orgpolicy.policyAdmin" \
  #--user-output-enabled false

# Grant roles/billing.user to the service account on the organization
echo "Adding role roles/billing.user..."
gcloud organizations add-iam-policy-binding \
  "${ORG_ID}" \
  --member="serviceAccount:${SA_ID}" \
  --role="roles/billing.user" \
  #--user-output-enabled false

# Grant roles/resourcemanager.folderCreator to the service account on the organization
echo "Adding role roles/resourcemanager.folderCreator..."
gcloud organizations add-iam-policy-binding \
  "${ORG_ID}" \
  --member="serviceAccount:${SA_ID}" \
  --role="roles/resourcemanager.folderCreator" \
  #--user-output-enabled false


# Grant roles/compute.networkAdmin to the service account on the organization
echo "Adding role roles/compute.networkAdmin..."
gcloud organizations add-iam-policy-binding \
  "${ORG_ID}" \
  --member="serviceAccount:${SA_ID}" \
  --role="roles/compute.networkAdmin" \
  #--user-output-enabled false

# Grant roles/cloudsql.admin to the service account on the organization for SQL admin
echo "Adding role roles/cloudsql.admin..."
gcloud organizations add-iam-policy-binding \
  "${ORG_ID}" \
  --member="serviceAccount:${SA_ID}" \
  --role="roles/cloudsql.admin" \
  #--user-output-enabled false

# Grant roles/iam.serviceAccountAdmin to the service account on the organization
echo "Adding role roles/iam.serviceAccountAdmin..."
gcloud organizations add-iam-policy-binding \
  "${ORG_ID}" \
  --member="serviceAccount:${SA_ID}" \
  --role="roles/iam.serviceAccountAdmin" \
  #--user-output-enabled false

# Grant roles/storage.admin to the service account on the organization
echo "Adding role roles/storage.admin..."
gcloud organizations add-iam-policy-binding \
  "${ORG_ID}" \
  --member="serviceAccount:${SA_ID}" \
  --role="roles/storage.admin" \
  #--user-output-enabled false

 # Grant roles/resourcemanager.projectIamAdmin to the Seed Service Account on the Seed Project
echo "Adding role roles/resourcemanager.projectIamAdmin..."
gcloud projects add-iam-policy-binding \
  "${SEED_PROJECT}" \
  --member="serviceAccount:${SA_ID}" \
  --role="roles/resourcemanager.projectIamAdmin" \
  #--user-output-enabled false

 # Grant roles/logging.configWriter to the Seed Service Account on the Seed Project
echo "Adding role roles/logging.configWriter..."
gcloud projects add-iam-policy-binding \
  "${SEED_PROJECT}" \
  --member="serviceAccount:${SA_ID}" \
  --role="roles/logging.configWriter" \
  #--user-output-enabled false

 # Grant roles/compute.imageUser to the Seed Service Account on the Seed Project
echo "Adding role roles/compute.imageUser..."
gcloud projects add-iam-policy-binding \
  "${SEED_PROJECT}" \
  --member="serviceAccount:${SA_ID}" \
  --role="roles/compute.imageUser" \
  #--user-output-enabled false

