#
# Run with: bash g3k_testsuite.sh
#
# NOTE: The tests in this testsuite.sh require a particular test environment
# that can run terraform and interact with kubernetes.
# The tests in g3k_testsuite.sh should run anywhere.
#
#
source "$GEN3_HOME/gen3/lib/utils.sh"

export GEN3_MANIFEST_HOME="${GEN3_HOME}/gen3/lib/testData"

gen3_load "gen3/lib/shunit"
gen3_load "gen3/gen3setup"

test_semver() {
  semver_ge "1.1.1" "1.1.0"; because $? "1.1.1 -ge 1.1.0"
  ! semver_ge "1.1.0" "1.1.1"; because $? "! 1.1.0 -ge 1.1.1"
  semver_ge "2.0.0" "1.10.22"; because $? "2.0.0 -ge 1.10.22"
}

test_colors() {
  expected="red red red"
  redTest=$(red_color "$expected")
  
  echo -e "red test: $redTest"
  # test does not work in zsh
  [[  -z "${BASH_VERSION}" || "$redTest" ==  "${RED_COLOR}${expected}${DEFAULT_COLOR}" ]]; because $? "Calling red_color returns red-escaped string: $redTest ?= $expected";

  expected="green green green"
  greenTest=$(red_color "$expected")
  echo -e "green test: $greenTest"
  echo "green test: $greenTest"
  # test does not work in zsh
  [[ -z "${BASH_VERSION}" || "$greenTest" == "$RED_COLOR${expected}$DEFAULT_COLOR" ]]; because $? "Calling green_color returns green-escaped string: $greenTest ?= $expected";
}

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
      gen3 gitops filter "${GEN3_HOME}/kube/services/$name/${name}-deploy.yaml" "$mpath" | sed 's/.*date:.*$//' > "$testFolder/${name}-${domain}-a.yaml"
      cat "$(dirname "$mpath")/expected${capName}Result.yaml" | sed 's/.*date:.*$//' > "$testFolder/${name}-${domain}-b.yaml"
      diff -w "$testFolder/${name}-${domain}-a.yaml" "$testFolder/${name}-${domain}-b.yaml"
      because $? "Manifest filter gave expected result for $name deployment with $domain manifest"
    done
  done
  gen3 gitops filter "${GEN3_MANIFEST_HOME}/bogusInput.yaml" "${GEN3_MANIFEST_HOME}/default/manifest.json" "k1" "the value is v1" "k2" "the value is v2" > "$testFolder/bogus-b.yaml"
  diff -w "${GEN3_MANIFEST_HOME}/bogusExpectedResult.yaml" "$testFolder/bogus-b.yaml"
  because $? "Manifest filter processed extra environment values ok"
}

test_mlookup() {
  local mpath # manifest path
  mpath="$(g3k_manifest_path test1.manifest.g3k)"
  [[ "$(g3k_config_lookup .versions.fence "$mpath")" == "quay.io/cdis/fence:master" ]];
  because $? "g3k_config_lookup found expected fence version: $(g3k_config_lookup .versions.fence "$mpath")"
  ! g3k_manifest_filter '.bogus.whatever' "$mpath";
  because $? 'g3k_manifest_filter gives non-zero exit code on jq expression failure'
  g3k_config_lookup '.versions.fence' "$mpath";
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
  GEN3_SOURCE_ONLY=true
  gen3_load "gen3/bin/roll"

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


test_configmaps() {
  GEN3_SOURCE_ONLY=true
  gen3_load "gen3/bin/gitops"

  local mpath
  local mpathGlobal
  mpath="$(g3k_manifest_path test1.manifest.g3k)"
  mpathGlobal="$(g3k_manifest_path manifest.global.g3k)"

  # Mock g3k_manifest_path to manifest with no global
  function g3k_manifest_path() { echo "$mpath"; }

  # Do not actually update the configmaps on a live environment
  # from test data
  function g3kubectl() {
    if [[ "$1" == "label" ]]; then
      echo "labeled"
    elif [[ "$1" == "create" ]]; then
      echo "created"
    elif [[ "$1" == "delete" ]]; then
      echo "deleted"
    elif [[ "$1" == "get" ]]; then
      echo "NAME"
    fi
    return 0
  }


  gen3_gitops_configmaps; because !$? "gen3_gitops_configmaps should exit with code 1 if the manifest does not have a global section"
  
  # Mock g3k_manifest_path to manifest with global
  function g3k_manifest_path() { echo "$mpathGlobal"; }
  gen3_gitops_configmaps | grep -q created; because $? "gen3_gitops_configmaps should create configmaps"
  gen3_gitops_configmaps | grep -q labeled; because $? "gen3_gitops_configmaps should label configmaps"
  g3kubectl delete configmaps -l app=manifest

  gen3_gitops_configmaps; 
  gen3_gitops_configmaps; because $? "gen3_gitops_configmaps should not bomb out, even if the configmaps already exist"
  gen3_gitops_configmaps | grep -q deleted; because $? "gen3_gitops_configmaps delete previous configmaps"
}

test_gitops_taglist() {
  gen3 gitops taglist | grep -E 'fence *[0-9]+\.[0-9]+\.[0-9]+'; because $? "gen3 gitops taglist should list some tag for fence"
}

test_gitops_logs() {
  gen3 logs rawq | jq -r .; because $? "gen3 logs rawq should cat a json format query block"
  gen3 logs vpc | grep -E '^devplanetv1 '; because $? "gen3 logs vpc should include the devplanetv1 vpc environment/log group"
}

shunit_runtest "test_semver"
shunit_runtest "test_colors"
shunit_runtest "test_env"
shunit_runtest "test_mpath"
shunit_runtest "test_mfilter"
shunit_runtest "test_mlookup"
shunit_runtest "test_loader"
shunit_runtest "test_random_alpha"
shunit_runtest "test_roll"
shunit_runtest "test_configmaps"
shunit_runtest "test_gitops_taglist"
shunit_runtest "test_gitops_logs"

if [[ "$G3K_TESTSUITE_SUMMARY" != "no" ]]; then
  # little hook, so gen3 testsuite can call through to this testsuite too ...
  echo "g3k summary"
  shunit_summary
fi
