#
# Run with: bash g3k_testsuite.sh
# Assume we're running in the directory for now ...
#
source "$GEN3_HOME/gen3/lib/utils.sh"

export GEN3_MANIFEST_HOME="${GEN3_HOME}/gen3/lib/testData"

gen3_load "gen3/lib/shunit"
gen3_load "gen3/gen3setup"

test_env() {
  [[ ! -z $GEN3_HOME ]]; because $? "kubes.sh defines the GEN3_HOME environment variable"
  [[ ! -z $GEN3_MANIFEST_HOME ]]; because $? "kubes.sh defines the GEN3_MANIFEST_HOME environment variable"
  [[ -d $GEN3_MANIFEST_HOME ]]; because $? "kubes.sh checks out cdis-manifest if necessary"
  [[ -d "${GEN3_MANIFEST_HOME}/test1.manifest.g3k" ]]; because $? "cdis-manifest includes a test1.manifest.g3k domain"
}

#
# Test g3k_manifest_path
#
test_mpath() {
  local mpath=$(g3k_manifest_path test1.manifest.g3k)
  [[ "$mpath" == "${GEN3_MANIFEST_HOME}/test1.manifest.g3k/manifest.json" ]]; 
  because $? "g3k_manifest_path prefers domain/manifest.json if available: $mpath ?= ${GEN3_MANIFEST_HOME}/test1.manifest.g3k/manifest.json"
  ! mpath=$(g3k_manifest_path bogus.manifest.g3k); because $? "The bogus manifest does not exist: $mpath"
  [[ "$mpath" == "${GEN3_MANIFEST_HOME}/bogus.manifest.g3k/manifest.json" ]]; 
  because $? "g3k_manfest_path maps to domain/manifest.json even if it does not exist: $mpath"

  export GEN3_GITOPS_FOLDER="/whatever"
  [[ "$(g3k_manifest_path)" == "$GEN3_GITOPS_FOLDER/manifest.json" ]]; 
  because $? "g3k_manifest_path respects the GEN3_GITOPS_FOLDER override variable"
}

#
# Test g3k_manifest_filter - also tests g3k_kv_filter
#
test_mfilter() {
  testFolder="${XDG_RUNTIME_DIR}/g3kTest/mfilter"
  /bin/rm -rf "$testFolder"
  mkdir -p -m 0700 "$testFolder"
  for name in fence sheepdog; do
    capName=Fence
    if [[ "$name" == "sheepdog" ]]; then capName=Sheepdog; fi
    for domain in test1.manifest.g3k default; do
      local mpath
      mpath="$(g3k_manifest_path test1.manifest.g3k)"
      # Note: date timestamp will differ between saved snapshot and fresh template processing
      echo "Writing: $testFolder/${name}-${domain}-a.yaml"
      g3k_manifest_filter "${GEN3_HOME}/kube/services/$name/${name}-deploy.yaml" "$mpath" | sed 's/.*date:.*$//' > "$testFolder/${name}-${domain}-a.yaml"
      cat "$(dirname "$mpath")/expected${capName}Result.yaml" | sed 's/.*date:.*$//' > "$testFolder/${name}-${domain}-b.yaml"
      diff -w "$testFolder/${name}-${domain}-a.yaml" "$testFolder/${name}-${domain}-b.yaml"
      because $? "Manifest filter gave expected result for $name deployment with $domain manifest"
    done
  done
  g3k_manifest_filter "${GEN3_MANIFEST_HOME}/bogusInput.yaml" "${GEN3_MANIFEST_HOME}/default/manifest.json" "k1" "the value is v1" "k2" "the value is v2" > "$testFolder/bogus-b.yaml"
  diff -w "${GEN3_MANIFEST_HOME}/bogusExpectedResult.yaml" "$testFolder/bogus-b.yaml"
  because $? "Manifest filter processed extra environment values ok"
}

test_mlookup() {
  export GEN3_GITOPS_FOLDER="${GEN3_MANIFEST_HOME}/test1.manifest.g3k"
  [[ "$(g3k_config_lookup .versions.fence)" == "quay.io/cdis/fence:master" ]];
  because $? "g3k_config_lookup found expected fence version: $(g3k_config_lookup .versions.fence)"
  ! g3k_manifest_filter '.bogus.whatever';
  because $? 'g3k_manifest_filter gives non-zero exit code on jq expression failure'
  g3k_config_lookup '.versions.fence';
  because $? 'g3k_manifest_filter gives zero exit code on jq expression match'
  # test with a toy .yaml file
  testFolder="${XDG_RUNTIME_DIR}/g3kTest/mlookup"
  /bin/rm -rf "$testFolder"
  mkdir -p -m 0700 "$testFolder"
  cat - > "$testFolder/toy.yaml" <<EOM
bla:
  foo: frick
  ugh: doh
EOM
  blaFoo=$(g3k_config_lookup '.bla.foo' "$testFolder/toy.yaml")
  because $? "g3k_config_lookup zero exit code for valid yaml lookup"
  [[ "$blaFoo" == "frick" ]];
  because $? "g3k_config_lookup got expected value from yaml: $blaFoo"
}

test_loader() {
  gen3_load "gen3/lib/testData/gen3_load/a"
  gen3_load "gen3/lib/testData/gen3_load/b"
  [[ "$GEN3_LOAD_A" -eq 1 && "$GEN3_LOAD_B" -eq 1 ]]; because $? "gen3_load loads a file once"
  gen3_load "gen3/lib/testData/gen3_load/a"
  gen3_load "gen3/lib/testData/gen3_load/b"
  [[ "$GEN3_LOAD_A" -eq 1 && "$GEN3_LOAD_B" -eq 1 ]]; because $? "gen3_load does not load a file twice"
  source "${GEN3_HOME}/gen3/lib/testData/gen3_load/a.sh"
  source "${GEN3_HOME}/gen3/lib/testData/gen3_load/b.sh"
  [[ "$GEN3_LOAD_A" -eq 2 && "$GEN3_LOAD_B" -eq 2 ]]; because $? "multi-load increments a counter"
  (! gen3_load "gen3/lib/testData/gen3_load/c"); because $? "gen3_load gives error for file that does not exist"
}

test_random_alpha() {
  local r1
  local r2
  r1="$(random_alphanumeric)"
  r2="$(random_alphanumeric 32)"
  [[ $(echo -n "$r1" | wc -m) == 32 ]]; because $? "random_alphanumeric defaults to 32 chars"
  [[ $(echo -n "$r2" | wc -m) == 32 ]]; because $? "random_alphanumeric generates 32 chars"
  [[ "$r1" != "$r2" ]]; because $? "random_alphanumeric generates random strings"
}

test_roll() {
  # Mock g3kubectl
  function g3kubectl() {
    echo "MOCK: g3kubectl $@"
  }
  local mpath
  mpath="$(g3k_manifest_path test1.manifest.g3k)"
  # Mock g3k_manifest_path
  function g3k_manifest_path() { echo "$mpath"; }
  g3k_roll sheepdog; because $? "roll sheepdog should be ok"
  ! g3k_roll frickjack; because $? "roll frickjack should not be ok - no yaml file"
  ! g3k_roll aws-es-proxy; because $? "roll aws-es-proxy should not be ok - no manifest entry"
}
test_gitops_home() {
  WORKSPACE="${WORKSPACE:-$HOME}"
  [[ $(g3k_get_gitops_home dev.planx-pla.net) == $WORKSPACE/dev.planx-pla.net ]]; because $? "dev.planx-pla.net GITOPS repo exists"
  [[ -z "$(g3k_get_gitops_home bogus.di.domain)" ]]; because $? "bogus.di.domain does not exist"
}

test_configmaps() {
  local mpath
  local mpathGlobal
  mpath="$(g3k_manifest_path test1.manifest.g3k)"
  mpathGlobal="$(g3k_manifest_path manifest.global.g3k)"

  # Mock g3k_manifest_path to manifest with no global
  function g3k_manifest_path() { echo "$mpath"; }
  g3k configmaps; because !$? "g3k configmaps should exit with code 1 if the manifest does not have a global section"
  
  # Mock g3k_manifest_path to manifest with global
  function g3k_manifest_path() { echo "$mpathGlobal"; }
  g3k configmaps | grep -q created; because $? "g3k configmaps should create configmaps"
  g3k configmaps | grep -q labeled; because $? "g3k configmaps should label configmaps"
  g3kubectl delete configmaps -l app=manifest
  g3k configmaps; 
  g3k configmaps; because $? "g3k configmaps should not bomb out, even if the configmaps already exist"
  g3k configmaps | grep -q deleted; because $? "g3k configmaps delete previous configmaps"
}

shunit_runtest "test_gitops_home"
shunit_runtest "test_env"
shunit_runtest "test_mpath"
shunit_runtest "test_mfilter"
shunit_runtest "test_mlookup"
shunit_runtest "test_loader"
shunit_runtest "test_random_alpha"
shunit_runtest "test_roll"
shunit_runtest "test_configmaps"

if [[ "$G3K_TESTSUITE_SUMMARY" != "no" ]]; then
  # little hook, so gen3 testsuite can call through to this testsuite too ...
  echo "g3k summary"
  shunit_summary
fi
