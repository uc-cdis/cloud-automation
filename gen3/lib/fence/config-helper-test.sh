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

python ./config-helper.py -r ../testData/gen3_fence/replace/to-replace.yaml -c ../testData/gen3_fence/replace/to-be-replaced.yaml -o tmp.yaml
assertFilesSame "replace configs to a yaml file" tmp.yaml ../testData/gen3_fence/replace/expected.yaml

python ./config-helper.py -e ../testData/gen3_fence/extract/template.yaml -c ../testData/gen3_fence/extract/extract-from.yaml -o tmp.json
assertFilesSame "extract secrets to a JSON file" tmp.json ../testData/gen3_fence/extract/expected.json

python ./config-helper.py -d ../testData/gen3_fence/remove/template.yaml  -c ../testData/gen3_fence/remove/remove-from.yaml -o tmp.yaml
assertFilesSame "delete secrets from a yaml file" tmp.yaml ../testData/gen3_fence/remove/expected.yaml

rm ./tmp.yaml
