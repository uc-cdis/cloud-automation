source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

# Update the passwords hashing algorithm to something supported by FIPS
update_pass() {
  db=$1
  username=$2
  password=$3
  gen3 psql $db -c "SET password_encryption  = 'scram-sha-256'; ALTER USER \""$username"\" with password '$password';"
  #gen3 psql $db -c "ALTER USER "$username" with password '$password';"
}

for name in indexd fence sheepdog peregrine; do
  username=$(gen3 secrets decode $name-creds creds.json | jq -r .db_username)
  password=$(gen3 secrets decode $name-creds creds.json | jq -r .db_password)
  update_pass $name $username $password
done

for name in wts metadata gearbox audit arborist access-backend argo_db requestor atlas ohdsi argo thor; do
  if [[ ! -z $(gen3 secrets decode $name-g3auto dbcreds.json) ]]; then
    username=$(gen3 secrets decode $name-g3auto dbcreds.json | jq -r .db_username)
    password=$(gen3 secrets decode $name-g3auto dbcreds.json | jq -r .db_password)
    update_pass $name $username $password
  fi
done
