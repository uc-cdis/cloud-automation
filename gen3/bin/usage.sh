#!/bin/bash

README="$GEN3_HOME/gen3/README.md"
cat "$README" - <<EOM
$README
-----------------------------------------

USAGE: gen3 [gen3-flags] command [command-options]
  * gen3-flags: the following flags are available
    - --dry-run 
    - --verbose
  * commands
    - help
    - status
    - workon AWS_PROFILE VPC_NAME
    - cd [home|work]
    - 
  * command-options: vary by command, but all support 'help' 
  * dependency check:
    - awscli: $(which aws)
    - terraform: $(which terraform)
    - jq: $(which jq)
    - md5sum: $(which md5sum)
    - base64: $(which base64)
    - awk, sed, head, tail, ... bash shell utils

  
EOM
