lastG3Kubectl=""
testRules="$(cat - <<EOM
{
  "fence": {
    "strategy": "auto",
    "min": 2,
    "max": 6
  },
  "indexd": {
    "strategy": "auto",
    "min": 2,
    "max": 6
  },
  "revproxy": {
    "strategy": "auto",
    "min": 2,
    "max": 6
  },
  "sheepdog": {
    "strategy": "pin",
    "num": 4 
  }
}
EOM
)"

g3k_manifest_path() {
  echo "$GEN3_HOME/gen3/lib/testData/default/manifest.json"
}


#
# Mock g3kubectl for scaling test
#
g3kubectl() {
  lastG3Kubectl="$@"
  gen3_log_info "scaling g3kubectl mock: $@"
  if [[ $# -gt 1 && "$2" == "configmaps" ]]; then
    cat - <<EOM
{
  "data": { "json": $testRules, "hostname": "test1.manifest.g3k" }
}
EOM
    return 0
  fi
}

test_scaling_rules() {
  export GEN3_SOURCE_ONLY=true
  gen3_load "gen3/bin/scaling"
  lastG3Kubectl=""
  local rules="$(scaling_cli rules)"
  [[ "$rules" == "$(jq -r . <<<"$testRules")" ]]; because $? "scaling rules match expected set: $rules"
}

test_scaling_manual() {
  export GEN3_SOURCE_ONLY=true
  gen3_load "gen3/bin/scaling"
  lastG3Kubectl=""
  scaling_cli apply rule '{"key":"fence", "value":{"strategy":"manual"}}'
  [[ 0 == $? && -z "$lastG3Kubectl" ]]; because $? "manual scaling should be noop"
}

test_scaling_pin() {
  export GEN3_SOURCE_ONLY=true
  gen3_load "gen3/bin/scaling"
  lastG3Kubectl=""
  scaling_cli apply rule '{"key":"fence-deployment", "value":{"strategy":"pin", "num":2}}'
  [[ 0 == $? && "$lastG3Kubectl" =~ ^patch ]]; because $? "pin scaling should patch a deployment"
}

test_scaling_auto() {
  export HPA_ON=yes
  export GEN3_SOURCE_ONLY=true
  gen3_load "gen3/bin/scaling"
  lastG3Kubectl=""
  scaling_cli apply rule '{"key":"fence-deployment", "value":{"strategy":"auto" }}'
  local result=$?
  [[ 0 == $result && "$lastG3Kubectl" =~ ^apply ]]; because $? "auto scaling should apply a hpa - got result: $result, $lastG3Kubectl"
}

test_scaling_fallback() {
  export HPA_ON=no
  export GEN3_SOURCE_ONLY=true
  gen3_load "gen3/bin/scaling"
  lastG3Kubectl=""
  scaling_cli apply rule '{"key":"fence-deployment", "value":{"strategy":"auto" }}'
  local result=$?
  [[ 0 == $result && "$lastG3Kubectl" =~ ^patch ]]; because $? "auto scaling without HPA should patch a deployment"
}


shunit_runtest "test_scaling_rules" "scaling,local"
shunit_runtest "test_scaling_manual" "scaling,local"
shunit_runtest "test_scaling_pin" "scaling"
shunit_runtest "test_scaling_auto" "scaling"
shunit_runtest "test_scaling_fallback" "scaling"
