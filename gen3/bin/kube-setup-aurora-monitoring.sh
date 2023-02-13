source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

# Verify that the DB is set up correctly. We'll need to either abort, or fix it ourselves if we can.

# Create the Datadog user
# TODO figure out how we're doing the password
# gen3 psql server1 -c "CREATE USER datadog WITH password '<PASSWORD>';"

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

  cat /home/aidan/fakeDatadogValues.yaml | yq 


# Check that everything is working