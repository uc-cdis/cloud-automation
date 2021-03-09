#!/bin/bash

# No! set -e

if [ -z "$JENKINS_HOME" ]; then
  # To simplify testing
  JENKINS_HOME=/var/jenkins_home
fi

if [ "$JENKINS_HOME" = "/tmp/var/jenkins_home" ]; then
  echo "ERROR: JENKINS_HOME points at temp space that will be overwritten: $JENKINS_HOME"
  exit 1
fi

if [ -z "$JENKINS_S3_PATH" ]; then
  JENKINS_S3_PATH="s3://cdis-terraform-state/Jenkins2Backup"
fi

# Setup ~/.aws to support cloud-automation/gen3 
mkdir -p ~/.aws
cat - > ~/.aws/config <<EOM
[profile jenkins]
output = json
region = us-east-1
EOM
cat - > ~/.aws/credentials <<EOM
[jenkins]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
EOM

if [ ! -d "$JENKINS_HOME/jobs" ]; then # restore from s3 is necessary
  if [ -d "$JENKINS_HOME" ]; then
    # download latest backup from S3 - collected via Pipelines/Backup :-)
    latestFile="$(aws s3 ls $JENKINS_S3_PATH/ | sort | grep .tar.xz | tail -1 | awk '{ print $4}')"
    if [ ! -z "$latestFile" ]; then
      S3PATH="$JENKINS_S3_PATH/$latestFile"
      echo "Downloading $S3PATH"
      aws s3 cp "$S3PATH" /tmp/backup.tar.xz
      tar xvf /tmp/backup.tar.xz -C /tmp
      mv /tmp/var/jenkins_home/* "$JENKINS_HOME/"
    else
      echo "No backups found under $JENKINS_S3_PATH"
    fi
  else
    echo "Jenkins home not in expected location: /var/jenkins_home"
  fi
fi

if [ -f /usr/local/bin/jenkins.sh ]; then
  source /usr/local/bin/jenkins.sh
else
  echo "Jenkins startup script not where expected: /usr/local/bin/jenkins.sh"
fi

