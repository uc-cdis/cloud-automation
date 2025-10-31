
#
# Test api_config/yaml_merge.py
#
test_yaml_merge() {
  local yaml1
  local yaml2
  local json3

  yaml1="$(mktemp "$XDG_RUNTIME_DIR/yaml1.yaml_XXXXXX")"
  yaml2="$(mktemp "$XDG_RUNTIME_DIR/yaml2.yaml_XXXXXX")"
  cat - > "$yaml1" <<EOM
A: 1
B: 2
EOM
  cat - > "$yaml2" <<EOM
C: 4
B: 3
EOM
  json3="$(python3.9 "$GEN3_HOME/apis_configs/yaml_merge.py" "$yaml1" "$yaml2")"; because $? "yaml_merge should succeed"
  [[ "1" == "$(jq -r .A <<<"$json3")" ]]; because $? ".A should be 1"
  /bin/rm "$yaml1"
  /bin/rm "$yaml2"
}


#
# Verfiy that gen3 gitops filter is generating valid yaml for various
# services and jobs that leverage the yaml_merge script
#
test_fence_yaml() {
  export GEN3_MANIFEST_HOME="${GEN3_HOME}/gen3/lib/testData"
  local mpath
  local yamlPath
  mpath="$(g3k_manifest_path test1.manifest.g3k)"; because $? "g3k_manifest_path works"
  for yamlPath in $(grep -r fence-config "$GEN3_HOME/kube/" | awk -F : '{ print $1 }' | grep 'yaml$' | sort -u); do
    gen3 gitops filter "$yamlPath" "$mpath" UNIQUE_BUCKET_NAME some-unique-name \
      STORAGE_CLASS "" \
      PUBLIC_BUCKET "" \
      REQUESTER_PAYS "" \
      GOOGLE_PROJECT_ID "" \
      PROJECT_AUTH_ID "" \
      ACCESS_LOGS_BUCKET "" | yq -r . > /dev/null;
    because $? "gen3 gitops filter works for $yamlPath"
  done
}


shunit_runtest "test_yaml_merge" "local,fencestuff"
shunit_runtest "test_fence_yaml" "local,fencestuff"
