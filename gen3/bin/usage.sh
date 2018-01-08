#!/bin/bash

cat - <<EOM
USAGE: gen3 [gen3-flags] command [command-options]
  * gen3-flags: the following flags are available
    - --dry-run 
    - --verbose
  * commands
    - help
    - status
  * command-options: vary by command, but all support 'help'
EOM
