#!/bin/bash

# MacOS has 'md5', linux has 'md5sum'
MD5=md5
if [[ $(uname -o) == "GNU/Linux" ]]; then
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

EOM
