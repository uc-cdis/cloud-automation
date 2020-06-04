#
# this should work in Jenkins - otherwise can export GEN3_PROMHOST=path/to/key.json
# to run locally
#
test_prometheus_query() {
  local query="sum by (envoy_cluster_name) (rate(evoy_cluster_upstream_rq_total{kubernetes_namespace=\"default\"}[12h]))"
  local result
  result="$(gen3 prometheus query "$query")" && jq -e -r . <<< "$result"; 
    because $? "prometheus test query $query worked ok - got $result"
}

test_prometheus_list() {
  local result
  result="$(gen3 prometheus list)" && jq -e -r . <<< "$result"; 
    because $? "prometheus list worked ok - got $result"
}

shunit_runtest "test_prometheus_list" "prometheus"
shunit_runtest "test_prometheus_query" "prometheus"
