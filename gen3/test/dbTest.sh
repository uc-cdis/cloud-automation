
test_db_psql() {
  [[ "$(gen3 db psql fence -c 'SELECT 1;' | awk '{ if(NR==3){ print $1; } }')" == "1" ]]; because $? "gen3 db psql fence works"
}

test_db_init() {
  unset JENKINS_HOME  # these functions normally don't work in Jenkins
  export GEN3_SOURCE_ONLY=true
  gen3_load "gen3/bin/db"
  unset GEN3_SOURCE_ONLY
  gen3_db_init; because $? "gen3 db_init should be ok"
  [[ "$(gen3 db psql server1 -c 'SELECT 1;' | awk '{ if(NR==3){ print $1; } }')" == "1" ]]; because $? "gen3 db psql server1 works"
  gen3_db_validate_server "server1"; because $? "server1 should be in the db farm"
  gen3_db_validate_server "server2"; because $? "server2 should be in the db farm"
  ! gen3_db_validate_server "server1000"; because $? "server1000 should not be in the db farm"
}

test_db_list() {
  unset JENKINS_HOME  # these functions normally don't work in Jenkins
  export GEN3_SOURCE_ONLY=true
  gen3_load "gen3/bin/db"
  unset GEN3_SOURCE_ONLY
  [[ $(gen3_db_list server1 | wc -l) -gt 0 ]]; because $? "gen3_db_list has non-zero result"
  [[ $(gen3_db_user_list server1 | wc -l) -gt 0 ]]; because $? "gen3_db_user_list has non-zero result"
  [[ "$(gen3 db server list | wc -l)" -gt 0 ]]; because $? "there should be some servers"
  gen3 db server list | grep server1; because $? "server1 is in the server list"
}

test_db_create() {
  unset JENKINS_HOME  # these functions normally don't work in Jenkins
  local serviceName
  local namespace
  serviceName="dbctest"
  namespace="$(gen3 db namespace)"

  [[ -n "$namespace" ]]; because $? "gen3_db_namespace should give a valid value: $namespace"
  gen3 klock lock dbctest dbctest 300 -w 300; because $? "must acquire a lock to run test_db_create"

  # cleanup from previous run if necessary
  g3kubectl delete secret "${serviceName}-g3auto"
  /bin/rm -rf "$(gen3_secrets_folder)/g3auto/${serviceName}"
  gen3 db psql server1 -c "DROP DATABASE \"${serviceName}_${namespace}\""
  gen3 db psql server1 -c "DROP USER \"${serviceName}_${namespace}\""
  
  gen3 db setup "$serviceName" "server1"; because $? "setup db should go ok"
  g3kubectl get secret "${serviceName}-g3auto"; because $? "setup db should create a secret in k8s"
  [[ -f "$(gen3_secrets_folder)/g3auto/${serviceName}/dbcreds.json" ]]; because $? "setup db should setup secrets file"
  gen3 db psql "$serviceName" -c 'SELECT 1'; because $? "should be able to connect to the new service"
  gen3 klock unlock dbctest dbctest
}

shunit_runtest "test_db_psql" "db"
shunit_runtest "test_db_init" "db"
shunit_runtest "test_db_list" "db"
shunit_runtest "test_db_create" "db"
