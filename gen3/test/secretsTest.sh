
test_secrets() {
  export WORKSPACE="$XDG_RUNTIME_DIR/testSecretsWorkspace-$$"
  export GEN3_SECRETS_HOME="$WORKSPACE/Gen3Secrets"

  unset JENKINS_HOME
  [[ "$(gen3_secrets_folder)" == "$WORKSPACE/Gen3Secrets" ]]; because $? "got expected secrets folder $(gen3_secrets_folder)"
  if [[ ! "$(gen3_secrets_folder)" == "$WORKSPACE/Gen3Secrets" ]]; then
    # tests below are destructive - do not run if not in test folder
    gen3_log_err "test_secrets" "bailing out - unexpected secrets folder location: $(gen3_secrets_folder)"
    return 1
  fi
  /bin/rm -rf "$WORKSPACE"
  mkdir -m 0700 -p "$(gen3_secrets_folder)/g3auto/testservice"
  [[ ! -d "$(gen3_secrets_folder)/.git" ]]; because $? "secrets folder .git does not exist before init"
  [[ ! -d "$WORKSPACE/backup" ]]; because $? "secrets backup does not exist before init"
  # setup some test secrets
  now="$(date)"
  echo "$now" > "$(gen3_secrets_folder)/g3auto/testservice/frickjack.txt"
  cat - > "$(gen3_secrets_folder)/creds.json" <<EOM
{
  "testservice": {
    "db_host": "host-$now",
    "db_username": "user-$now",
    "db_password": "pass-$now",
    "db_database": "db-$now"
  }
}
EOM
  echo "Scan $(gen3_secrets_folder)"
  find "$(gen3_secrets_folder)"
  gen3 secrets sync; because $? "secrets sync should have non-zero exit code"
  [[ -d "$(gen3_secrets_folder)/.git" ]]; because $? "secrets sync initializes git if necessary"
  [[ -d "$WORKSPACE/backup" ]]; because $? "secrets sync initializes backup if necessary"
  gen3 secrets commit; because $? "2nd commit should not be necessary - should be ok"
  ! gen3 secrets decode bogus; because $? "secrets decode should fail on bogus secret"
  ! gen3 secrets decode testservice-g3auto bogus; because $? "secrets decode should fail on bogus key"
  gen3 secrets decode testservice-g3auto frickjack.txt; because $? "secrets decode should succeed on valid key"
  [[ "$(gen3 secrets decode testservice-g3auto frickjack.txt)" == "$now" ]]; because $? "secrets decode should match $now"
  gen3 secrets decode testservice-g3auto | grep "$now"; because $? "secrets decode should scan all keys if no key given"
  [[ "$(gen3 secrets decode testservice-creds creds.json | jq -r .db_host)" == "host-$now" ]]; because $? "creds secrets decode should match host-$now"
  # cleanup
  /bin/rm -rf "$WORKSPACE"
}


shunit_runtest "test_secrets" "secrets"
