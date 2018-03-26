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
    - md5: $(which $MD5)
    - base64: $(which base64)
    - awk, sed, head, tail, ... bash shell utils

  * command summary (details above) - each command supports a --help option:
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
EOM
