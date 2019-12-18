#!/bin/bash
#
# Little fence config helper
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

if [[ -z "$1" || "$1" =~ ^-*help$ ]]; then
  gen3 help fence-config
  exit 0
fi

command="$1"
shift

case "$command" in
"extract-secrets")
  inputConfigYaml="$1"
  outputPath="$2"
  secretTemplateYaml="$3"
  if [[ -z "$secretTemplateYaml" ]]; then
    secretTemplateYaml=$GEN3_HOME/gen3/lib/fence/fence-secret-config-template.yaml
  fi
  python3 $GEN3_HOME/gen3/lib/fence/config-helper.py -e $secretTemplateYaml -c $inputConfigYaml -o $outputPath
  ;;
"remove-secrets")
  inputConfigYaml="$1"
  outputPath="$2"
  secretTemplateYaml="$3"
  if [[ -z "$secretTemplateYaml" ]]; then
    secretTemplateYaml=$GEN3_HOME/gen3/lib/fence/fence-secret-config-template.yaml
  fi
  python3 $GEN3_HOME/gen3/lib/fence/config-helper.py -d $secretTemplateYaml -c $inputConfigYaml -o $outputPath
  ;;
"merge")
  curl -s https://raw.githubusercontent.com/uc-cdis/fence/master/fence/config-default.yaml > ./config-default.yaml
  inputSecretConfig="$1"
  inputPublicConfig="$2"
  outputPath="$3"
  if [[ -z "$outputPath" ]]; then
    outputPath=./merged-config.yaml
  fi
  python3 $GEN3_HOME/gen3/lib/fence/config-helper.py -r $inputSecretConfig -c ./config-default.yaml -o ./tmp.yaml
  python3 $GEN3_HOME/gen3/lib/fence/config-helper.py -r $inputPublicConfig -c ./tmp.yaml -o $outputPath
  rm ./config-default.yaml ./tmp.yaml
  ;;
"split")
  secretTemplateYaml=$GEN3_HOME/gen3/lib/fence/fence-secret-config-template.yaml
  inputConfigYaml="$1"
  outputPublicConfig="$2"
  outputSecretConfig="$3"
  python3 $GEN3_HOME/gen3/lib/fence/config-helper.py -d $secretTemplateYaml -c $inputConfigYaml -o $outputPublicConfig
  python3 $GEN3_HOME/gen3/lib/fence/config-helper.py -e $secretTemplateYaml -c $inputConfigYaml -o $outputSecretConfig
  ;;
"replace")
  input="$1"
  replaceWith="$2"
  output="$3"
  python3 $GEN3_HOME/gen3/lib/fence/config-helper.py -r $replaceWith -c $input -o $output
  ;;
*)
  gen3 help fence-config
  exit 1
  ;;
esac
