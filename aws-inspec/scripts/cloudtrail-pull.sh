#!/bin/bash

if [[ "$1" == "" || "$2" == "" || "$3" == "" || "$4" == "" ]]; then
  echo "Usage: pull-cloudtrail [CONFIG] [BUCKET_NAME] [ACCOUNT_NUMBER] [REGION]"
  exit 1
fi

YEAR=`date +%Y`
MONTH=`date +%m`
DAY=`date +%d`

CONFIG=$1
BUCKET_NAME=$2
ACCOUNT_NUMBER=$3
REGION=$4

FILE_TO_PULL=`s3cmd -c ${CONFIG} ls s3://${BUCKET_NAME}/AWSLogs/${ACCOUNT_NUMBER}/CloudTrail/${REGION}/${YEAR}/${MONTH}/${DAY}/* | tail -1 | awk '{print $4}'`
FILE_FOR_GUNZIP=`basename ${FILE_TO_PULL}`
FINAL_FILE=`basename ${FILE_TO_PULL}.gz`

s3cmd get ${FILE_TO_PULL}
gunzip ${FILE_FOR_GUNZIP}
cat ${FINAL_FILE} | /opt/scripts/jq -r -M .Records[] -c >> /var/log/cloudtrail/${ACCOUNT_NUMBER}/cloudtrail.json
rm -f ${FINAL_FILE}