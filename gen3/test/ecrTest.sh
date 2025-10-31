test_ecr_registry() {
  local reg
  reg="$(gen3 ecr registry)" && [[ "$reg" == "707767160287.dkr.ecr.us-east-1.amazonaws.com" ]]; because $? "gen3 ecr registry got expected value: $reg"
}

test_ecr_login() {
  gen3 ecr login; because $? "gen3 ecr login works"
}


test_ecr_setup() {
  if [[ -n "$JENKINS_HOME" ]]; then
    # give ourselves permissions on /run/containerd/containerd.sock
    sudo chown root:sudo /run/containerd/containerd.sock; because $? "ecr_setup modified containerd.sock"
  fi
}

test_ecr_copy() {
  test_ecr_setup
  gen3 ecr copy "$(gen3 ecr registry)/gen3/fence:2020.05" "$(gen3 ecr registry)/gen3/fence:test_ecr_copy"; because $? "able to copy fence:2020.05 to fence:test_ecr_copy"
}

test_ecr_sync() {
  test_ecr_setup
  gen3 ecr quay-sync "fence" "2020.05"; because $? "able to sync fence:2020.05"
}

test_ecr_list() {
  local repoList
  local numRepo
  repoList="$(gen3 ecr list)" && numRepo="$(wc -l <<< "$repoList")" && [[ "$numRepo" -gt 3 ]]; because $? "gen3 ecr list looks ok: $repoList"
}

shunit_runtest "test_ecr_setup" "ecr"
shunit_runtest "test_ecr_login" "ecr"
shunit_runtest "test_ecr_registry" "local,ecr"
shunit_runtest "test_ecr_copy" "ecr"
shunit_runtest "test_ecr_list" "ecr"
shunit_runtest "test_ecr_sync" "ecr"
