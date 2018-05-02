#
# Run with: bash shunit_testsuite.sh
# Assume we're running in the directory for now ...
#
G3K_TESTSUITE_DIR=$(dirname "${BASH_SOURCE:-$0}")
GEN3_HOME="${GEN3_HOME:-$(cd "${G3K_TESTSUITE_DIR}/../.." && pwd)}"
export GEN3_HOME
export GEN3_MANIFEST_HOME="${G3K_TESTSUITE_DIR}/testData"

source "$G3K_TESTSUITE_DIR/shunit.sh"
source "$G3K_TESTSUITE_DIR/../../kube/kubes.sh"

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
  mpath=$(g3k_manifest_path bogus.manifest.g3k)
  [[ "$mpath" == "${GEN3_MANIFEST_HOME}/default/manifest.json" ]]; 
  because $? "g3k_manfiest_path falls through to default/manifest.json if domain/manifest.json not present: $mpath"
}

#
# Test g3k_manifest_filter - also tests g3k_kv_filter
#
test_mfilter() {
  testFolder="${XDG_RUNTIME_DIR}/g3kTest/mfilter"
  /bin/rm -rf "$testFolder"
  mkdir -p -m 0700 "$testFolder"
  for name in fence sheepdog; do
    for domain in test1.manifest.g3k default.bogus; do
      local mpath="$(g3k_manifest_path test1.manifest.g3k)"
      # Note: date timestamp will different between saved snapshot and fresh template processing
      echo "Writing: $testFolder/${name}-${domain}-a.yaml"
      g3k_manifest_filter "${GEN3_HOME}/kube/services/$name/${name}-deploy.yaml" "$mpath" | sed 's/.*date:.*$//' > "$testFolder/${name}-${domain}-a.yaml"
      cat "$(dirname "$mpath")/expected${name^}Result.yaml" | sed 's/.*date:.*$//' > "$testFolder/${name}-${domain}-b.yaml"
      diff -w "$testFolder/${name}-${domain}-a.yaml" "$testFolder/${name}-${domain}-b.yaml"
      because $? "Manifest filter gave expected result for $name deployment with $domain manifest"
    done
  done
  g3k_manifest_filter "${GEN3_MANIFEST_HOME}/bogusInput.yaml" "${GEN3_MANIFEST_HOME}/default/manifest.json" "k1" "the value is v1" "k2" "the value is v2" > "$testFolder/bogus-b.yaml"
  diff -w "${GEN3_MANIFEST_HOME}/bogusExpectedResult.yaml" "$testFolder/bogus-b.yaml"
  because $? "Manifest filter processed extra environment values ok"
}

shunit_runtest "test_env"
shunit_runtest "test_mpath"
shunit_runtest "test_mfilter"
shunit_summary

