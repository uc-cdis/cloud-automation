#!/bin/bash

# No! set -e

if [ ! -d "/var/jenkins_home/jobs" ]; then
  # download latest backup from S3 - collected via Pipelines/Backup :-)
  latestFile="$(aws s3 ls s3://cdis-terraform-state/JenkinsBackup/ | sort | tail -1 | awk '{ print $4}')"
  aws s3 cp "s3://cdis-terraform-state/JenkinsBackup/$latestFile" /tmp/backup.tar.xz
  tar xvf /tmp/backup.tar.xz -C /tmp
  mv /tmp/var/jenkins_home/* /var/jenkins_home/
fi

source /usr/local/bin/jenkins.sh
