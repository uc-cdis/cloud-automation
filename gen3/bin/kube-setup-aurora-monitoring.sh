source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

# Verify that the DB is set up correctly. We'll need to either abort, or fix it ourselves if we can.

# Create the Datadog user
datadogPsqlPassword="$(jq -r .datadog_db_password < $(gen3_secrets_folder)/datadog/datadog_db_user.json)"
if [[ -z "$datadogPsqlPassword" ]]; then
  # Generate a new password for the datadog user in psql
  datadogPsqlPassword=$(random_alphanumeric)

  # update creds.json
  if [ ! -d "$(gen3_secrets_folder)/datadog" ]
  then
    mkdir "$(gen3_secrets_folder)/datadog"
  fi

  cp "$GEN3_HOME/kube/services/datadog/datadog_db_user.json" "$(gen3_secrets_folder)/datadog/datadog_db_user.json"
  jq ".datadog_db_password=\"$datadogPsqlPassword\"" "$GEN3_HOME/kube/services/datadog/datadog_db_user.json" > "$(gen3_secrets_folder)/datadog/datadog_db_user.json"

  # Create the Datadog user in the database
  gen3 psql server1 -c "CREATE USER datadog WITH password $datadogPsqlPassword;"
fi

# Get all of the DBs, so that we can create the necessary components in all of them
databases=$(gen3 psql server1 -c "SELECT datname FROM pg_database;")
databases=$(echo $databases | cut -c 47-)
# For an explanation of this one, it uses parameter expansion: https://mywiki.wooledge.org/BashGuide/Parameters#Parameter_Expansion
# This matches the pattern, (* rows), against the end of the databases string, and deletes the shortest match
databases="${databases%(* rows)}"

# Now we turn it into an array
databaseArray=($databases)


# Loop through every database, creating the schema and function

for db in "${databaseArray[@]}"
do
  echo "gen3 psql server1 -d $db -t  <<SQL |
    CREATE SCHEMA datadog; 
      GRANT USAGE ON SCHEMA datadog TO datadog; 
      GRANT USAGE ON SCHEMA public TO datadog;
      GRANT pg_monitor TO datadog;
      CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
SQL"

  echo "gen3 psql server1 -d $DB -t <<SQL |
    CREATE OR REPLACE FUNCTION datadog.explain_statement(
      l_query TEXT,
      OUT explain JSON
    )
   
    RETURNS SETOF JSON AS
    $$
    DECLARE
    curs REFCURSOR;
    plan JSON;

    BEGIN
      OPEN curs FOR EXECUTE pg_catalog.concat('EXPLAIN (FORMAT JSON) ', l_query);
      FETCH curs INTO plan;
      CLOSE curs;
      RETURN QUERY SELECT plan;
    END;
    $$
    LANGUAGE 'plpgsql'
    RETURNS NULL ON NULL INPUT
    SECURITY DEFINER;
SQL"
done

# Set up the agent
#==============================

# Get the instances in the Aurora cluster
  # We'll take the name of the cluster as the first argument, so we won't need to go digging for that. Instead, we'll just
  # pull out connection strings and ports for each instance

instances=$(aws rds describe-db-instances --filters "Name=db-cluster-id,Values=$1" --no-paginate | jq '.DBInstances[].Endpoint.Address,.DBInstances[].Endpoint.Port')

postgresString=""
for instance in "${instances[@]}" 
do
  datadogUserPassword=$(jq .datadog_db_password $(gen3_secrets_folder)/datadog/datadog_db_user.json)
  instanceArray=($instance)
  postgresString+=$(cat /home/aidan/cloud-automation/kube/services/datadog/postgres.yaml | yq --arg url ${instanceArray[0]} '.instances[0].host = $url' | yq --arg password $datadogUserPassword --yaml-output '.instances[0].password = $password')
done

echo "$(cat kube/services/datadog/values.yaml | yq --arg endpoints "$postgresString" --yaml-output '.datadog.confd."postgres.yaml" = $endpoints')"


# Check that everything is working