
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
  json3="$(python3 "$GEN3_HOME/apis_configs/yaml_merge.py" "$yaml1" "$yaml2")"; because $? "yaml_merge should succeed"
  [[ "1" == "$(jq -r .A <<<"$json3")" ]]; because $? ".A should be 1"
  /bin/rm "$yaml1"
  /bin/rm "$yaml2"
}
