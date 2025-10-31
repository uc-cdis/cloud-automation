test_infra_subcommand() {
  local subcommand
  for subcommand in vpc-list subnet-list ec2-list rds-list es-list; do
    gen3 infra $subcommand; because $? "infra $subcommand should work"
  done
}

test_infra_json2csv() {
  (cat - <<EOM
{ "a": "A1", "b": "B1", "c": "C1" }
{ "a": "A2", "b": "B2", "c": "C2" }
EOM
   ) | gen3 infra json2csv; because $? "infra json2csv should work"
}

shunit_runtest "test_infra_subcommand" "infra"
shunit_runtest "test_infra_json2csv" "local,infra"
