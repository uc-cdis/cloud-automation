#!/bin/bash

# MacOS has 'md5', linux has 'md5sum'
MD5=md5
if [[ $(uname -s) == "Linux" ]]; then
  MD5=md5sum
fi

README="$GEN3_HOME/gen3/README.md"
cat "$README" - <<EOM
$README
-----------------------------------------

USAGE: gen3 [gen3-flags] command [command-options]
  * dependency check:
    - awscli: $(which aws)
    - terraform: $(which terraform)
    - jq: $(which jq)
    - yq: $(which yq)
    - md5: $(which $MD5)
    - base64: $(which base64)
    - gcloud: $(which gcloud)
    - kubectl: $(kubectl version server)
    - awk, sed, head, tail, ... bash shell utils

  * terraform related commands (details above) - each command supports a --help option:
    - aws 
      * shortcut for gen3 arun aws 
    - arun shell command
      * run the given shell command line with AWS secrets set
        based on the current workspace - supports assume-role and mfa
    - help
    - ls
    - refresh
    - status
    - tfapply
    - tfplan
    - tfoutput
    - trash
    - workon {profile} {workspace}
      * supports workspace types: _adminvm, _databucket, _snapshot, _squidvm, 
               _user, commons VPC is default

  * kubernetes related commands
    - backup - backup home directory to vpc's S3 bucket
    - devterm - open a terminal session in a dev pod
    - ec2_reboot PRIVATE-IP - reboot the ec2 instance with the given private ip
    - jobpods JOBNAME - list pods associated with given job
    - joblogs JOBNAME - get logs from first result of jobpods
    - pod PATTERN - grep for the first pod name matching PATTERN
    - pods PATTERN - grep for all pod names matching PATTERN
    - psql SERVICE 
        - where SERVICE is one of sheepdog, indexd, fence
    - random [length=32]
        - random string (ex - password) of length (default 32)
    - reload
        - reload the gen3 function library - useful after
          updating the cloud-automation folder
    - replicas DEPLOYMENT-NAME REPLICA-COUNT
    - roll DEPLOYMENT-NAME
        Apply the current manifest to the specified deployment - triggers
        and update in most deployments (referencing GEN3_DATE_LABEL) even 
        if the version does not change.
    - runjob JOBNAME k1 v1 k2 v2 ...
      - JOBNAME also maps to cloud-automation/kube/services/JOBNAME-job.yaml
    - testsuite
    - update_config CONFIGMAP-NAME YAML-FILE
    
EOM
