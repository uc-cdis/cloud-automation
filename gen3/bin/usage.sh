#!/bin/bash

# MacOS has 'md5', linux has 'md5sum'
MD5=md5
if [[ $(uname -s) == "Linux" ]]; then
  MD5=md5sum
fi

README="$GEN3_HOME/gen3/README.md"
cat - <<EOM
$README
-----------------------------------------

USAGE: gen3 [gen3-flags] command [subcommand] [options]
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
    - es [subcommand] - elastic search helpers
        o alias
        o dump
        o export
        o import
        o indices
        o port-forward
    - filter file.yaml [k1 v1 k2 v2 ...]
        apply the manifest filter that gen3 roll and gen3 runjob use to the given file -
        gen3 roll deployment == gen3 filter deployment.yaml | kubectl apply -f -
    - jobpods JOBNAME - list pods associated with given job
    - joblogs JOBNAME - get logs from first result of jobpods
    - kube-lock
    - kube-unlock
    - kube-wait4pods
    - pod PATTERN - grep for the first pod name matching PATTERN
    - pods PATTERN - grep for all pod names matching PATTERN
    - psql SERVICE 
        o where SERVICE is one of sheepdog, indexd, fence
    - random [length=32]
        o random string (ex - password) of length (default 32)
    - reload
        o reload the gen3 function library - useful after
          updating the cloud-automation folder
    - replicas DEPLOYMENT-NAME REPLICA-COUNT
    - roll DEPLOYMENT-NAME [key1 value1 key2 value2 ...]
        Apply the current manifest to the specified deployment - triggers
        and update in most deployments (referencing GEN3_DATE_LABEL) even 
        if the version does not change. - ex:
          gen3 roll fence DEBUG_FLAG True
    - runjob JOBNAME k1 v1 k2 v2 ...
        o JOBNAME maps to cloud-automation/kube/services/JOBNAME-job.yaml
        o also support: runjob path/to/name-job.yaml or name-cronjob.yaml
    - testsuite
    - update_config CONFIGMAP-NAME YAML-FILE
    
EOM
