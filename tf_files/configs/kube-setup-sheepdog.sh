#!/bin/bash
#
# Deploy sheepdog into existing commons - assume configs are already configured
# for sheepdog to re-use the userapi db.
# This fragment is pasted into kube-services.sh by kube.tf.
#

set -e

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
python render_creds.py secrets

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
gdcapi_db_host=$(jq -r .gdcapi.db_host < creds.json)
gdcapi_db_database=$(jq -r .gdcapi.db_database < creds.json)
export PGPASSWORD="$gdcapi_db_password"

for user in sheepdog peregrine; do
  new_db_user=$(jq -r .${user}.db_username < creds.json)
  new_db_password=$(jq -r .${user}.db_password < creds.json)

  if [[ "$gdcapi_db_user" != "$new_db_user" ]]; then
    new_user_count=$(psql -t -U $gdcapi_db_user -h $gdcapi_db_host -d $gdcapi_db_database -c "SELECT COUNT(*) FROM pg_catalog.pg_user WHERE usename='$new_db_user';")
    if [[ $new_user_count -eq 0 ]]; then
      echo "Creating postgres user $new_db_user"
      psql -t -U $gdcapi_db_user -h $gdcapi_db_host -d $gdcapi_db_database -c "CREATE USER $new_db_user WITH PASSWORD '$new_db_password';"
      psql -t -U $gdcapi_db_user -h $gdcapi_db_host -d $gdcapi_db_database -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO $new_db_user;"
      if [[ "$new_db_user" =~ ^sheepdog ]]; then
        psql -t -U $gdcapi_db_user -h $gdcapi_db_host -d $gdcapi_db_database -c "GRANT ALL ON ALL TABLES IN SCHEMA pubic TO $new_db_user;"
      fi
    fi
  fi
done

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
  python render_creds.py gdcapi_db
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
