# test configmaps folder dry run
test_configmaps_folder_dryrun() {
  local testFolder="${GEN3_HOME}/gen3/lib/testData/manifests/frickjack"
  local dryRunCommand
  dryRunCommand="$(gen3 gitops configmaps "$testFolder" --dryRun)"; because $? "gitops configmaps should work with folder $testFolder"
  gen3_log_info "configmaps $testFolder command: $dryRunCommand"
  [[ "$dryRunCommand" =~ frickjack.json ]]; because $? "gitops configmaps folder command looks ok"
}

# create configmaps from folder
test_configmaps_folder() {
  local testFolder="${GEN3_HOME}/gen3/lib/testData/manifests/frickjack"
  local dryRunCommand
  gen3 gitops configmaps "$testFolder"; because $? "gitops configmaps should work with folder $testFolder"
  local namespace
  namespace="$(g3kubectl get configmap manifest-frickjack -o json | jq -e -r '.data["user-namespace"]')"; because $? "configmap looks ok"
  [[ "$namespace" == "jupyter-pods" ]]; because $? "configmap got right namespace"
}

#
# Test g3k_manifest_path
#
test_mpath() {
  export GEN3_MANIFEST_HOME="${GEN3_HOME}/gen3/lib/testData"
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
  export GEN3_MANIFEST_HOME="${GEN3_HOME}/gen3/lib/testData"
  testFolder="${XDG_RUNTIME_DIR}/$$/g3kTest/mfilter"
  /bin/rm -rf "$testFolder"
  mkdir -p -m 0700 "$testFolder"
  local name
  for name in fence sheepdog; do
    local capName=Fence
    if [[ "$name" == "sheepdog" ]]; then capName=Sheepdog; fi
    local domain
    for domain in test1.manifest.g3k default; do
      local mpath
      mpath="$(g3k_manifest_path test1.manifest.g3k)"
      # Note: date timestamp will differ between saved snapshot and fresh template processing
      gen3_log_info "Writing: $testFolder/${name}-${domain}-a.yaml"
      gen3 gitops filter "${GEN3_HOME}/kube/services/$name/${name}-deploy.yaml" "$mpath" | sed 's/.*date:.*$//' > "$testFolder/${name}-${domain}-a.yaml"
      cat "$(dirname "$mpath")/expected${capName}Result.yaml" | sed 's/.*date:.*$//' > "$testFolder/${name}-${domain}-b.yaml"
      diff -w "$testFolder/${name}-${domain}-a.yaml" "$testFolder/${name}-${domain}-b.yaml"
      because $? "Manifest filter gave expected result for $name deployment with $domain manifest"
    done
  done
  gen3 gitops filter "${GEN3_MANIFEST_HOME}/bogusInput.yaml" "${GEN3_MANIFEST_HOME}/default/manifest.json" "k1" "the value is v1" "k2" "the value is v2" > "$testFolder/bogus-b.yaml"
  diff -w "${GEN3_MANIFEST_HOME}/bogusExpectedResult.yaml" "$testFolder/bogus-b.yaml"
  because $? "Manifest filter processed extra environment values ok"
  /bin/rm -rf "$testFolder"
}

test_mlookup() {
  export GEN3_MANIFEST_HOME="${GEN3_HOME}/gen3/lib/testData"
  local mpath # manifest path
  mpath="$(g3k_manifest_path test1.manifest.g3k)"
  [[ "$(g3k_config_lookup .versions.fence "$mpath")" == "quay.io/cdis/fence:master" ]];
  because $? "g3k_config_lookup found expected fence version: $(g3k_config_lookup .versions.fence "$mpath")"
  ! g3k_manifest_filter '.bogus.whatever' "$mpath";
  because $? 'g3k_manifest_filter gives non-zero exit code on jq expression failure'
  g3k_config_lookup '.versions.fence' "$mpath";
  because $? 'g3k_manifest_filter gives zero exit code on jq expression match'
  # test with a toy .yaml file
  testFolder="${XDG_RUNTIME_DIR}/$$/g3kTest/mlookup"
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
  /bin/rm -rf "$testFolder"
}

test_loader() {
  export GEN3_MANIFEST_HOME="${GEN3_HOME}/gen3/lib/testData"
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

test_roll_path() {
  export GEN3_MANIFEST_HOME="${GEN3_HOME}/gen3/lib/testData"
  gen3_load "gen3/bin/gitops"

  ! tpath="$(gen3 gitops rollpath bogus "" 2> /dev/null)"; because $? "bogus service yaml does not exist"
  [[ "$tpath" =~ /kube/services/bogus/bogus-deploy.yaml$ ]]; because $? "gen3 gitops rollpath gives expected bogus path $tpath"
  ! tpath="$(gen3 gitops rollpath bogus-canary "" 2> /dev/null)"; because $? "bogus-canary service yaml does not exist"
  [[ "$tpath" =~ /kube/services/bogus/bogus-canary-deploy.yaml$ ]]; because $? "gen3 gitops rollpath gives expected bogus-canary path $tpath"
  tpath="$(gen3 gitops rollpath fence "")"; because $? "fence service yaml exists"
  [[ "$tpath" =~ /kube/services/fence/fence-deploy.yaml$ ]]; because $? "gen3 gitops rollpath gives expected fence path $tpath"
  tpath="$(gen3 gitops rollpath fence-canary "")"; because $? "fence-canary service yaml exists"
  [[ "$tpath" =~ /kube/services/fence/fence-canary-deploy.yaml$ ]]; because $? "gen3 gitops rollpath gives expected fence-canary path $tpath"
  ! tpath="$(gen3 gitops rollpath fence 1.2.3)"; because $? "fence service v1.2.3 yaml does not exist"
  [[ "$tpath" =~ /kube/services/fence/fence-deploy-1.2.3.yaml$ ]]; because $? "gen3 gitops rollpath gives expected fence v1.2.3 path $tpath"

  local mpath
  mpath="$(g3k_manifest_path test1.manifest.g3k)"
  # Mock g3k_manifest_path
  function g3k_manifest_path() { echo "$mpath"; }

  tpath="$(gen3_roll_path fence)"; because $? "fence service does exist, and mock manifest exists"
  [[ "$tpath" =~ /kube/services/fence/fence-deploy.yaml$ ]]; because $? "gen3 gitops rollpath gives expected fence no-version path $tpath"
}

test_roll() {
  export GEN3_MANIFEST_HOME="${GEN3_HOME}/gen3/lib/testData"
  gen3_load "gen3/bin/roll"

  # Mock g3kubectl
  function g3kubectl() {
    echo "MOCK: g3kubectl $@"
  }
  local mpath
  mpath="$(g3k_manifest_path test1.manifest.g3k)"
  # Mock g3k_manifest_path
  function g3k_manifest_path() { echo "$mpath"; }
  gen3_roll sheepdog; because $? "roll sheepdog should be ok"
  ! gen3_roll frickjack; because $? "roll frickjack should not be ok - no yaml file"
  ! gen3_roll aws-es-proxy; because $? "roll aws-es-proxy should not be ok - no manifest entry"
}


test_configmaps() {
  export GEN3_MANIFEST_HOME="${GEN3_HOME}/gen3/lib/testData"
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
  gen3_log_info "gitops taglist is not used - skipping slow test"
  return 0
  gen3 gitops taglist | grep -E 'fence *[0-9]+\.[0-9]+\.[0-9]+'; because $? "gen3 gitops taglist should list some tag for fence"
}

test_gitops_logs() {
  gen3 logs rawq | jq -r .; because $? "gen3 logs rawq should cat a json format query block"
  gen3 logs vpc | grep -E '^devplanetv1 '; because $? "gen3 logs vpc should include the devplanetv1 vpc environment/log group"
}

test_time_since() {
  gen3_time_since test_time_since is 0; because $? "gen3_time_since with 0 timeout should be ok"
  ! gen3_time_since test_time_since is 5; because $? "gen3_time_since with 5 second timeout should have to wait"
  sleep 6
  gen3_time_since test_time_since is 5; because $? "gen3_time_since with 5 second timeout should pass after sleeping 5 seconds"
}

test_secrets_folder() {
  vpc_name=SecretName
  secretFolder="$(gen3_secrets_folder)"
  [[ "$secretFolder" == "$(dirname $GEN3_HOME)/Gen3Secrets" ]]; because $? "gen3_secrets_folder gave expected result: $secretFolder"
}

shunit_runtest "test_configmaps_folder_dryrun" "local,gitops"
shunit_runtest "test_configmaps_folder" "gitops"
shunit_runtest "test_mpath" "local,gitops"
shunit_runtest "test_mfilter" "local,gitops"
shunit_runtest "test_mlookup" "local,gitops"
shunit_runtest "test_loader" "local,gitops"
shunit_runtest "test_random_alpha" "local,gitops"
shunit_runtest "test_roll" "local,gitops"
shunit_runtest "test_roll_path" "local,gitops"
shunit_runtest "test_configmaps" "local,gitops"
shunit_runtest "test_gitops_taglist" "local,gitops"
shunit_runtest "test_gitops_logs" "local,gitops"
shunit_runtest "test_time_since" "local,gitops"
shunit_runtest "test_secrets_folder" "local,gitops"
