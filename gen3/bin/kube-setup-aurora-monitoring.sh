source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

databaseArray=()
databaseFarmArray=()

# This function is going to retrieve and return all the top-level entries from creds.json, that has the db items we want.
# This way, we can use this information while we're creating schemas and the like
get_all_dbs() {
  databases=$(jq 'to_entries[] | select (.value.db_password) | .key' $(gen3_secrets_folder)/creds.json)

  OLD_IFS=$IFS
  IFS=$'\n' databaseArray=($databases)
  IFS=$OLD_IFS
}

get_all_dbs_db_farm() {
  databases=$(jq 'to_entries[] | .key' $(gen3_secrets_folder)/g3auto/dbfarm/servers.json)

  OLD_IFS=$IFS
  IFS=$'\n' databaseFarmArray=($databases)
  IFS=$OLD_IFS
}

create_new_datadog_user() {
  # Generate a new password for the datadog user in psql
  datadogPsqlPassword=$(random_alphanumeric)

  # update creds.json
  if [ ! -d "$(gen3_secrets_folder)/datadog" ]
  then
    mkdir "$(gen3_secrets_folder)/datadog"
  fi

  if [ ! -s "$(gen3_secrets_folder)/datadog/datadog_db_users" ]
  then
    echo "{}" > "$(gen3_secrets_folder)/datadog/datadog_db_users.json"
  fi

  output=$(jq --arg host "$1" --arg password "$datadogPsqlPassword" '.[$host].datadog_db_password=$password' "$(gen3_secrets_folder)/datadog/datadog_db_users.json")
  echo "$output" > "$(gen3_secrets_folder)/datadog/datadog_db_users.json"

  username=$(jq --arg host "$1" 'map(select(.db_host==$host))[0] | .db_username' $(gen3_secrets_folder)/g3auto/dbfarm/servers.json | tr -d '"')
  password=$(jq --arg host "$1" 'map(select(.db_host==$host))[0] | .db_password' $(gen3_secrets_folder)/g3auto/dbfarm/servers.json | tr -d '"')

  # Create the Datadog user in the database
  if PGPASSWORD=$password psql -h "$1" -U "$username" -c "SELECT 1 FROM pg_roles WHERE rolname='datadog'" | grep -q 1;
  then
    PGPASSWORD=$password psql -h "$1" -U "$username" -c "ALTER USER datadog WITH password '$datadogPsqlPassword';"
  else
    PGPASSWORD=$password psql -h "$1" -U "$username" -c "CREATE USER datadog WITH password '$datadogPsqlPassword';"
  fi

  echo $datadogPsqlPassword
}

get_datadog_db_password() {
  # Create the Datadog user
  datadogPsqlPassword="$(jq --arg host "$1" '.[$host].datadog_db_password' < $(gen3_secrets_folder)/datadog/datadog_db_users.json)"
  if [[ -z "$datadogPsqlPassword" ]]
  then
    datadogPsqlPassword=$(create_new_datadog_user $1)
  fi

  echo $datadogPsqlPassword
}

create_schema_and_function() {
  svc=$(echo $1 | tr -d '"')
  host=$(jq --arg service "$svc" '.[$service].db_host' $(gen3_secrets_folder)/creds.json | tr -d '"')
  database=$(jq --arg service "$svc" '.[$service].db_database' $(gen3_secrets_folder)/creds.json | tr -d '"')

  username=$(jq --arg host "$host" 'map(select(.db_host==$host))[0] | .db_username' $(gen3_secrets_folder)/g3auto/dbfarm/servers.json | tr -d '"')
  password=$(jq --arg host "$host" 'map(select(.db_host==$host))[0] | .db_password' $(gen3_secrets_folder)/g3auto/dbfarm/servers.json | tr -d '"')

  ddPass=$(get_datadog_db_password $host)

  PGPASSWORD=$password psql -h $host -U $username -d $database -t <<SQL |
    CREATE SCHEMA datadog; 
      GRANT USAGE ON SCHEMA datadog TO datadog; 
      GRANT USAGE ON SCHEMA public TO datadog;
      GRANT pg_monitor TO datadog;
      CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
SQL

  PGPASSWORD=$password psql -h $host -U $username -d $database -t <<SQL |
    CREATE OR REPLACE FUNCTION datadog.explain_statement(
      l_query TEXT,
      OUT explain JSON
    )
   
    RETURNS SETOF JSON AS
    \$\$
    DECLARE
    curs REFCURSOR;
    plan JSON;

    BEGIN
      OPEN curs FOR EXECUTE pg_catalog.concat('EXPLAIN (FORMAT JSON) ', l_query);
      FETCH curs INTO plan;
      CLOSE curs;
      RETURN QUERY SELECT plan;
    END;
    \$\$
    LANGUAGE 'plpgsql'
    RETURNS NULL ON NULL INPUT
    SECURITY DEFINER;
SQL

  gen3_log_info "Succesfully added the function and schema"
}

if [ $# -eq 0 ]; then
    echo "Error: No argument provided. You must provide the name of the Aurora cluster to operate against"
    exit 1
fi

get_all_dbs databaseArray

# Loop through every database, creating the schema and function
for db in "${databaseArray[@]}"
do
  create_schema_and_function $db
done


# Set up the agent
#==============================

# Get the instances in the Aurora cluster
  # We'll take the name of the cluster as the first argument, so we won't need to go digging for that. Instead, we'll just
  # pull out connection strings and ports for each instance

instances=$(aws rds describe-db-instances --filters "Name=db-cluster-id,Values=$1" --no-paginate | jq '.DBInstances[].Endpoint.Address,.DBInstances[].Endpoint.Port' | tr -d '"')
clusterEndpoint=$(aws rds describe-db-cluster-endpoints --db-cluster-identifier "$1" | jq ' .DBClusterEndpoints[0].Endpoint' | tr -d '"')

postgresString=""
for instance in "${instances[@]}" 
do
  instanceArray=($instance)
  datadogUserPassword=$(jq --arg instance "$clusterEndpoint" '.[$instance].datadog_db_password' $(gen3_secrets_folder)/datadog/datadog_db_users.json | tr -d '"')
  postgresString+=$(cat ${GEN3_HOME}/kube/services/datadog/postgres.yaml | yq --arg url ${instanceArray[0]} --yaml-output '.instances[0].host = $url' | yq --arg password $datadogUserPassword --yaml-output '.instances[0].password = $password')
done

confd=$(yq -n --yaml-output --arg postgres "$postgresString" '.clusterAgent.confd."postgres.yaml" = $postgres | .clusterChecksRunner.enabled = true')

#We'll need two ways to do this, one for commons where Datadog is managed by ArgoCD, and another for commons where 
#it's directly installed

if kubectl get applications.argoproj.io -n argocd datadog-application &> /dev/null
then
  gen3_log_info "We detected an ArgoCD application named 'datadog-application,' so we're modifying that"

  patch=$(yq -n --yaml-output --arg confd "$confd" '.spec.source.helm.values = $confd')
  
  echo "$patch" > /tmp/confd.yaml

  kubectl patch applications.argoproj.io datadog-application --type merge -n argocd --patch-file /tmp/confd.yaml

else
  gen3_log_info "We didn't detect an ArgoCD application named 'datadog-application,' so we're going to reinstall the DD Helm chart"
  
  (cat kube/services/datadog/values.yaml | yq --arg endpoints "$postgresString" --yaml-output '.clusterAgent.confd."postgres.yaml" = $endpoints | .clusterChecksRunner.enabled = true') > $(gen3_secrets_folder)/datadog/datadog_values.yaml
  helm repo add datadog https://helm.datadoghq.com --force-update 2> >(grep -v 'This is insecure' >&2)
  helm repo update 2> >(grep -v 'This is insecure' >&2)
  helm upgrade --install datadog -f "$(gen3_secrets_folder)/datadog/datadog_values.yaml" datadog/datadog -n datadog --version 3.6.4 2> >(grep -v 'This is insecure' >&2)
fi