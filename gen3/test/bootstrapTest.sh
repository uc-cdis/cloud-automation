test_bootstrap_template() {
  local config
  config="$(gen3 bootstrap template)"; because $? "bootstrap template runs ok"
  [[ -n "$config" ]] && (gen3 bootstrap template | jq -r .); because $? "bootstrap template is valid json"
}

test_bootstrap_fenceconfig() {
  local templateFolder="$GEN3_HOME/gen3/lib/bootstrap/templates"
  local secretConf="$templateFolder/Gen3Secrets/apis_configs/fence-config.yaml"
  local publicConf="$templateFolder/cdis-manifest/manifests/fence/fence-config-public.yaml"
  [[ -f "$secretConf" ]] && yq -r . < "$secretConf" > /dev/null; 
    because $? "secret template exists and is valid yaml: $secretConf"
  [[ -f "$publicConf" ]] && yq -r . < "$secretConf" > /dev/null;
    because $? "public template exists and is valid yaml: $secretConf"
  python3.9 "$GEN3_HOME/apis_configs/yaml_merge.py" "$publicConf" "$secretConf" | yq -r . > /dev/null;
    because $? "yaml_perge public private should yield valid yaml"
}

shunit_runtest "test_bootstrap_template" "bootstrap,local"
shunit_runtest "test_bootstrap_fenceconfig" "bootstrap,local"
