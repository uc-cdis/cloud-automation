#!/bin/bash
# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


set -e
set -u

# check for input variables
if [ $# -lt 3 ]; then
  echo
  echo "Usage: $0 <commons serviceAccount> <seed project in csoc> <csoc project id>"
  echo
  echo "  commons serviceAccount"
  echo "  csoc seed project id"
  echo "  csoc project id"
  echo
  exit 1
fi

 # Seed Project
echo "Verifying CSOC Seed project..."
SEED_PROJECT="$(gcloud projects list --format="value(projectId)" --filter="$2")"

if [[ $SEED_PROJECT == "" ]];
then
   echo "The Seed Project does not exist. Exiting."
  exit 1;
fi

 # CSOC Project
echo "Verifying CSOC project..."
CSOC_PROJECT="$(gcloud projects list --format="value(projectId)" --filter="$3")"

if [[ $CSOC_PROJECT == "" ]];
then
   echo "The CSOC Project does not exist. Exiting."
  exit 1;
fi

 # Build array of buckets in $SEED_PROJECT
array="$(gsutil ls -p "$SEED_PROJECT")"

 # Loop through array and assign permissions to $SEED_PROJECT
for i in "${array[@]}"
do
   echo $i
   gsutil iam ch serviceAccount:$1:objectCreator,objectViewer $i
done

 # CSOC Seed permissions
echo "Adding to CSOC Seed network admin"
gcloud projects add-iam-policy-binding \
 "${SEED_PROJECT}" \
 --member="serviceAccount:${1}" \
 --role="roles/compute.networkAdmin" \
 --user-output-enabled false

 # CSOC Seed permissions
echo "Adding Security Admin to $CSOC_PROJECT"
gcloud projects add-iam-policy-binding \
 "${CSOC_PROJECT}" \
 --member="serviceAccount:${1}" \
 --role="roles/compute.securityAdmin" \
 --user-output-enabled false

 # CSOC permissions
echo "Adding to CSOC storage"

 # Build array of buckets in $CSOC_PROJECT
array="$(gsutil ls -p "$CSOC_PROJECT")"

 # Loop through array and assign permissions to $SEED_PROJECT
for i in "${array[@]}"
do
   echo $i
   gsutil iam ch serviceAccount:$1:roles/storage.legacyBucketOwner $i
done
