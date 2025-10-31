
test_db_psql() {
  [[ "$(gen3 db psql fence -c 'SELECT 1;' | awk '{ if(NR==3){ print $1; } }')" == "1" ]]; because $? "gen3 db psql fence works"
}

test_db_init() {
  gen3_load "gen3/bin/db"
  gen3_db_init; because $? "gen3 db_init should be ok"
  [[ "$(gen3 db psql server1 -c 'SELECT 1;' | awk '{ if(NR==3){ print $1; } }')" == "1" ]]; because $? "gen3 db psql server1 works"
  gen3_db_validate_server "server1"; because $? "server1 should be in the db farm"
  gen3_db_validate_server "server2"; because $? "server2 should be in the db farm"
  ! gen3_db_validate_server "server1000"; because $? "server1000 should not be in the db farm"
}

test_db_list() {
  gen3_load "gen3/bin/db"
  [[ $(gen3_db_list server1 | wc -l) -gt 0 ]]; because $? "gen3_db_list has non-zero result"
  [[ $(gen3_db_user_list server1 | wc -l) -gt 0 ]]; because $? "gen3_db_user_list has non-zero result"
  [[ "$(gen3 db server list | wc -l)" -gt 0 ]]; because $? "there should be some servers"
  gen3 db server list | grep server1; because $? "server1 is in the server list"
}

test_db_random_server() {
  gen3_load "gen3/bin/db"
  gen3_db_random_server; because $? "gen3_db_random_server should run fine"
  local name
  name="$(gen3_db_random_server)"
  [[ "$name" =~ ^server[0-9]+$ ]]; because $? "gen3_db_random_server should return serverN - $name"
}


test_db_namespace() {
  local ns
  ns="$(gen3 db namespace)"
  [[ -n "$ns" && "$ns" != "null" ]]; because $? "gen3 db namespace looks valid: $ns"
}

test_db_create() {
  unset JENKINS_HOME  # these functions normally don't work in Jenkins
  local serviceName
  local namespace
  serviceName="dbctest"
  namespace="$(gen3 db namespace)"
  if [[ ! -f "$(gen3_secrets_folder)/creds.json" ]]; then
    # gen3 db setup checks that creds.json exists to avoid accidental execution - 
    # let's bypass that check - setup a temp secrets folder
    local tempRoot="$(mktemp -d "$XDG_RUNTIME_DIR/testDbCreate_XXXXXX")"
    export GEN3_SECRETS_HOME="${tempRoot}/Gen3Secrets"
    [[ "$(gen3_secrets_folder)" == $GEN3_SECRETS_HOME ]]; because $? "Temp secrets setup worked as expected"
    mkdir -p "$(gen3_secrets_folder)"
    echo '{}' > "$(gen3_secrets_folder)/creds.json"
  fi
  [[ -n "$namespace" ]]; because $? "gen3_db_namespace should give a valid value: $namespace"
  local klockOwner="dbctest_$$"
  gen3 klock lock dbctest "$klockOwner" 300 -w 300; because $? "must acquire a lock to run test_db_create"

  # cleanup from previous run if necessary
  g3kubectl delete secret "${serviceName}-g3auto"
  /bin/rm -rf "$(gen3_secrets_folder)/g3auto/${serviceName}"
  gen3 db psql server1 -c "DROP DATABASE \"${serviceName}_${namespace}\""
  gen3 db psql server1 -c "DROP USER \"${serviceName}_${namespace}\""
  
  gen3 db setup "$serviceName" "server1"; because $? "setup db should go ok"
  g3kubectl get secret "${serviceName}-g3auto"; because $? "setup db should create a secret in k8s"
  [[ -f "$(gen3_secrets_folder)/g3auto/${serviceName}/dbcreds.json" ]]; because $? "setup db should setup secrets file"
  gen3 db psql "$serviceName" -c 'SELECT 1'; because $? "should be able to connect to the new service db"
  ! (echo "no" | gen3 db reset "$serviceName"); because $? "db reset should fail without user confirmation"
  (yes | gen3 db reset "$serviceName"); because $? "db reset should re-create the database"
  gen3 db psql "$serviceName" -c 'SELECT 1'; because $? "should be able to connect to the new service db after reset"
  
  local serverName
  serverName="$(gen3 db creds "$serviceName" | jq -r '.g3FarmServer')"
  [[ "$serverName" == "server1" ]]; because $? "db creds includes new service the farm server: $serverName"
  
  gen3 klock unlock dbctest "$klockOwner"
}

test_db_creds() {
  local serverName
  serverName="$(gen3 db creds fence | jq -r '.g3FarmServer')"
  [[ "$serverName" =~ ^server[0-9]+$ ]]; because $? "db creds includes the farm server: $serverName"
}

test_db_services() {
  (gen3 db services | grep peregrine > /dev/null); because $? "gen3 db services includes peregrine"
}

test_db_snapshot_list() {
  local snapshotJson
  snapshotJson="$(gen3 db snapshot list server2)"; because $? "gen3 db snapshot list server2 should work"
  local snapCount
  snapCount="$(jq -e -r '.DBClusterSnapshots | length' <<<"$snapshotJson")"; 
    because $? "snap list json has expected structure"
  [[ "$snapCount" =~ ^[0-9]+$ && "$snapCount" -gt 0 ]]; because $? "server1 has at least 1 snapshot"
}

test_db_snapshot_take() {
  gen3 db snapshot take server2 --dryrun; because $? "gen3 db snapshot take server2 should work"
}

test_db_backup_restore() {
  local service
  for service in indexd fence sheepdog; do
    local backupFile="$(mktemp "$XDG_RUNTIME_DIR/$service.backup_XXXXXX")"
    gen3 db backup $service > "$backupFile"; because $? "gen3 db backup $service should work"
    local newCreds
    local oldCreds
    newCreds="$(gen3 db restore $service "$backupFile" 2> /dev/null)"; because $? "gen3 db restore $service should work"
    /bin/rm "$backupFile"
    oldCreds="$(gen3 db creds $service)"; because $? "gen3 db creds $service should work"
    local newDb
    local oldDb
    newDb="$(jq -r -e .db_database <<< "$newCreds")"; because $? "$service new creds should include .db_database"
    oldDb="$(jq -r -e .db_database <<< "$oldCreds")"; because $? "$service old creds should include .db_database"
    [[ "$newDb" != "$oldDb" ]]; because $? "$service restore should create a new db: $newDb ?= $oldDb"
    # cleanup
    gen3 psql aurora -c "DROP DATABASE $newDb;" || true
  done
}

shunit_runtest "test_db_backup_restore" "db"
shunit_runtest "test_db_init" "db"
shunit_runtest "test_db_psql" "db"
shunit_runtest "test_db_random_server" "db"
shunit_runtest "test_db_list" "db"
shunit_runtest "test_db_namespace" "db"
shunit_runtest "test_db_create" "db"
shunit_runtest "test_db_creds" "db"
shunit_runtest "test_db_services" "db"
shunit_runtest "test_db_snapshot_list" "db"
shunit_runtest "test_db_snapshot_take" "db"
