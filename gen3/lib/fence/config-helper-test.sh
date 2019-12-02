#!/bin/bash

assertFilesSame() {
  local testName
  local outputFilePath
  local expectedResultPath
  testName="$1"
  outputFilePath="$2"
  expectedResultPath="$3"

  if [[ ! -f $outputFilePath ]]; then
    echo "Error: no output result"
    exit 1
  fi
  cmpRes=`diff $outputFilePath $expectedResultPath -b -B`
  cmpStatus=$?
  if [[ $cmpStatus -eq 0 ]];then
    echo "Pass: \"$testName\""
  else
    echo "Fail: \"$testName\""
    echo "$cmpRes"
    exit 1
  fi
}

tmpSecretJSONFile="./secret.json"
tmpPubYamlFile="./pub.yaml"
secretTemplate="../testData/gen3_fence/simple-secret-template.yaml"
configYaml="../testData/gen3_fence/test-simple-config.yaml"
configTemplateYaml="../testData/gen3_fence/test-simple-config-default.yaml"

python ./config-helper.py -e $secretTemplate -c $configYaml > $tmpSecretJSONFile
assertFilesSame "extract secrets to a JSON file" $tmpSecretJSONFile ../testData/gen3_fence/expected-extracted-secrets.json

python ./config-helper.py -d $secretTemplate -c $configYaml > $tmpPubYamlFile
assertFilesSame "delete secrets from a yaml file" $tmpPubYamlFile ../testData/gen3_fence/expected-public-configs.yaml

python ./config-helper.py -r $tmpSecretJSONFile -c ../testData/gen3_fence/test-simple-config-default.yaml > tmp1.yaml
python ./config-helper.py -r $tmpPubYamlFile -c tmp1.yaml > tmp.yaml
assertFilesSame "merge (i.e., inject secrets and pub) configs to a yaml file" tmp.yaml ../testData/gen3_fence/expected-merged-configs.yaml

rm $tmpPubYamlFile $tmpSecretJSONFile $tmpYamlFile
