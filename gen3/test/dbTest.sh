
test_db_psql() {
  [[ "$(gen3 psql fence -c 'SELECT 1;' | awk '{ if(NR==3){ print $1; } }')" == "1" ]]; because $? "gen3 psql fence works"
}

test_db_init() {
  unset JENKINS_HOME  # these functions normally don't work in Jenkins
  export GEN3_SOURCE_ONLY=true
  gen3_load "gen3/bin/db"
  unset GEN3_SOURCE_ONLY
  gen3_db_init; because $? "gen3 db_init should be ok"
  [[ "$(gen3 psql server1 -c 'SELECT 1;' | awk '{ if(NR==3){ print $1; } }')" == "1" ]]; because $? "gen3 psql server1 works"
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
}

shunit_runtest "test_db_psql" "db"
shunit_runtest "test_db_init" "db"
shunit_runtest "test_db_list" "db"
