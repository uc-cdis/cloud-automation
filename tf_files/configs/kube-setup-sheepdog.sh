#!/bin/bash
#
# Deploy sheepdog into existing commons - assume configs are already configured
# for sheepdog to re-use the userapi db.
# This fragment is pasted into kube-services.sh by kube.tf.
#

set -e

export G3AUTOHOME=${G3AUTOHOME:-~/cloud-automation}
export RENDER_CREDS="${G3AUTOHOME}/tf_files/configs/render_creds.py"

if [ ! -f "${RENDER_CREDS}" ]; then
  echo "ERROR: ${RENDER_CREDS} does not exist"
fi

vpc_name=${vpc_name:-$1}
if [ -z "${vpc_name}" ]; then
   echo "Usage: bash kube-setup-sheepdog.sh vpc_name"
   exit 1
fi
if [ ! -d ~/"${vpc_name}" ]; then
  echo "~/${vpc_name} does not exist"
  exit 1
fi

cd ~/${vpc_name}_output
python "${RENDER_CREDS}" secrets

cd ~/${vpc_name}

if ! kubectl get secrets/sheepdog-secret > /dev/null 2>&1; then
  kubectl create secret generic sheepdog-secret --from-file=wsgi.py=./apis_configs/sheepdog_settings.py
fi

if [[ -z "$(kubectl get configmaps/global -o=jsonpath='{.data.dictionary_url}')" ]]; then
  echo "ERROR: configmaps/global does not include dictionary_url"
  echo "... update and apply ${vpc_name}/00configmap.json, then retry this script"
  exit 1
fi

kubectl apply -f services/sheepdog/sheepdog-deploy.yaml

#
# Create the 'sheepdog' and 'peregrine' postgres user if necessary
#
cd ~/${vpc_name}_output

if ! psql --help > /dev/null; then
  export DEBIAN_FRONTEND=noninteractive
  sudo -E apt install -y postgresql-client
fi
if ! jq --help > /dev/null; then
  export DEBIAN_FRONTEND=noninteractive
  sudo -E apt install -y jq
fi

gdcapi_db_user=$(jq -r .gdcapi.db_username < creds.json)
gdcapi_db_password=$(jq -r .gdcapi.db_password < creds.json)
sheepdog_db_user=$(jq -r .sheepdog.db_username < creds.json)
sheepdog_db_password=$(jq -r .sheepdog.db_password < creds.json)
peregrine_db_user=$(jq -r .peregrine.db_username < creds.json)
gdcapi_db_host=$(jq -r .gdcapi.db_host < creds.json)
gdcapi_db_database=$(jq -r .gdcapi.db_database < creds.json)
export PGPASSWORD="$gdcapi_db_password"

declare -a sqlList
      
# Create peregrine and sheepdog db users if necessary
for user in sheepdog peregrine; do
  new_db_user=$(jq -r .${user}.db_username < creds.json)
  new_db_password=$(jq -r .${user}.db_password < creds.json)

  if [[ "$gdcapi_db_user" != "$new_db_user" ]]; then
    new_user_count=$(psql -t -U $gdcapi_db_user -h $gdcapi_db_host -d $gdcapi_db_database -c "SELECT COUNT(*) FROM pg_catalog.pg_user WHERE usename='$new_db_user';")
    if [[ $new_user_count -eq 0 ]]; then
      echo "Creating postgres user $new_db_user"
      sql="CREATE USER $new_db_user WITH PASSWORD '$new_db_password';"
      echo "Running: $sql"
      psql -t -U $gdcapi_db_user -h $gdcapi_db_host -d $gdcapi_db_database -c "$sql"
    fi
  fi
done

# Grant permissions to peregrine
sqlList=(
  "GRANT SELECT ON ALL TABLES IN SCHEMA public TO $peregrine_db_user;"
  "ALTER DEFAULT PRIVILEGES GRANT SELECT ON TABLES TO $peregrine_db_user;"
);
for sql in "${sqlList[@]}"; do
  echo "Running: $sql"
  psql -t -U $gdcapi_db_user -h $gdcapi_db_host -d $gdcapi_db_database -c "$sql";
done

# GRANT permissions to sheepdog
declare -a sqlList;
if [[ "$gdcapi_db_user" != "$sheepdog_db_user" ]]; then
  # sheepdog needs some extra permissions if it is not already the db owner
  sqlList=(
    "GRANT ALL ON ALL TABLES IN SCHEMA public TO $sheepdog_db_user;"
    "GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO $sheepdog_db_user;"
    "GRANT ALL ON SCHEMA public TO $sheepdog_db_user;"
    "ALTER DEFAULT PRIVILEGES GRANT ALL ON TABLES TO $sheepdog_db_user;"
    "ALTER DEFAULT PRIVILEGES GRANT ALL ON SEQUENCES TO $sheepdog_db_user;"
  );
  for sql in "${sqlList[@]}"; do
    echo "Running: $sql"
    psql -t -U $gdcapi_db_user -h $gdcapi_db_host -d $gdcapi_db_database -c "$sql";
  done  
  # sheepdog user needs to grant peregrine privileges 
  # on postgres stuff sheepdog creates in the future if sheepdog user is not the
  # same as the 'gdcapi' user - which is the case when migrating legacy commons ...
  sql="ALTER DEFAULT PRIVILEGES GRANT SELECT ON TABLES TO $peregrine_db_user;"
  echo "Running: $sql"
  PGPASSWORD="$sheepdog_db_password" psql -t -U "$sheepdog_db_user" -h $gdcapi_db_host -d $gdcapi_db_database -c "$sql"
fi

cd ~/${vpc_name}

#
# Note: the 'create_gdcapi_db' flag is set in
#   kube-services.sh
#   The assumption here is that we only create the db once -
#   when we run 'kube-services.sh' at cluster init time
#   This setup block is not necessary when migrating an existing userapi commons to fence.
#
if [[ -z "${gdcapi_snapshot}" && "${create_gdcapi_db}" = "true" && ( ! -f .rendered_gdcapi_db ) ]]; then
  cd ~/${vpc_name}_output; 
  python "${RENDER_CREDS}" gdcapi_db
  cd ~/${vpc_name}
  # Avoid doing this more than once ...
  touch .rendered_gdcapi_db
fi
kubectl apply -f services/sheepdog/sheepdog-service.yaml

cat <<EOM
The sheepdog services has been deployed onto the k8s cluster.
You'll need to update the reverse-proxy nginx config
to make the commons start using the sheepdog service (and retire gdcapi for submission).
Run the following commands to make that switch:

kubectl apply -f services/revproxy/00nginx-config.yaml

# update_config is a function in cloud-automation/kube/kubes.sh
source ~/cloud-automation/kube/kubes.sh
patch_kube revproxy-deployment
EOM
