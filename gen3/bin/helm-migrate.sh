source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

# Check what apps are deployed

# Do DB backup of appropriate apps. 

# - arborist
# - wts
# - indexd
# - fence
# - sheepdog
# - metadata




# DB NAME in helm? Overrideable? 

GEN3_TEMPLATE_FOLDER="${GEN3_HOME}/gen3/lib/bootstrap/helm"
GEN3_HELM_MIGRATE_FOLDER="${HOME}/helm-migrate"


gen3_db_help() {
  gen3 help helm-migrate
}

# helper function
array_contains () {
    local seeking=$1; shift
    local in=1
    for element; do
        if [[ $element == "$seeking" ]]; then
            in=0
            break
        fi
    done
    return $in
}


gen3_helm_dump_db() {
    local serviceName
    local force
    if [[ $# -lt 1 || -z "$1" ]]; then
        gen3_log_err "gen3_migrate_helm_db" "must specify serviceName"
        return 1
    fi

    serviceName="$1"
    if [[ "$serviceName" == "peregrine" ]]; then
        # gen3_log_err "gen3_migrate_helm_db" "may not reset peregrine - only sheepdog"
        return
    fi


    requires_db_dump=("audit" "indexd" "fence" "metadata" "sheepdog" "wts")
    requires_es_dump=("guppy")


    # check if service requires db dump for migration.
    # Currently only sheepdog, metadata, and indexd are being dumped
    # Arborist policies get created by useryaml job
    # Fence - I am on the fence about migrating it. Need more input. 
    
    # if [[ " ${requires_db_dump[@]} " =~ " ${serviceName} " ]]; then
    if gen3 db creds $serviceName > /dev/null 2>&1; then 
        gen3_log_info "Dumping ${serviceName}."
        mkdir -p ${GEN3_HELM_MIGRATE_FOLDER}/pgdumps
        gen3 db backup $serviceName > ${GEN3_HELM_MIGRATE_FOLDER}/pgdumps/"${serviceName}".sql
    fi

    if [[ " ${requires_es_dump[@]} " =~ " ${serviceName} " ]]; then
        gen3_log_info "Dumping ES indices for ${serviceName}."
        # Subshell
        (
            gen3 es port-forward
            sleep 5
            indices=$(g3k_manifest_lookup .${serviceName}.indices[].index)
            for index in $indices; do 
                gen3_log_info $index
                if gen3 es health > /dev/null 2>&1; then 
                    gen3_log_info "ES healthy. Dumping index"
                    mkdir -p ${GEN3_HELM_MIGRATE_FOLDER}/elasticsearch
                    gen3 es dump $index > ${GEN3_HELM_MIGRATE_FOLDER}/elasticsearch/${index}.json
                    gen3 es mapping $index > ${GEN3_HELM_MIGRATE_FOLDER}/elasticsearch/${index}_mapping.json
                else 
                    gen3_log_err "ES is not healthy. Try running 'gen3 es health' to verify"
                    exit
                fi
            done
        )
    fi
}


gen3_helm_service_creds() {
    local serviceName
    if [[ $# -lt 1 || -z "$1" ]]; then
        gen3_log_err "gen3_helm_service_creds" "must specify serviceName"
        return 1
    fi

    serviceName="$1"
    
    if gen3 db creds $service > /dev/null 2>&1; then 
        gen3_log_info  "Adding DB configuration for $service"

        creds=$(gen3 db creds $service)
        host=$(echo $creds | jq -r .db_host)
        user=$(echo $creds | jq -r .db_username)
        pass=$(echo $creds | jq -r .db_password)
        db=$(echo $creds | jq -r .db_database)
        

        yq -yi "."\"$service\"".postgres.dbCreate=false" ${GEN3_HELM_MIGRATE_FOLDER}/values.yaml
        yq -yi "."\"$service\"".postgres.host="\"$host\" ${GEN3_HELM_MIGRATE_FOLDER}/values.yaml
        yq -yi "."\"$service\"".postgres.username="\"$user\" ${GEN3_HELM_MIGRATE_FOLDER}/values.yaml
        yq -yi "."\"$service\"".postgres.password="\"$pass\" ${GEN3_HELM_MIGRATE_FOLDER}/values.yaml
        yq -yi "."\"$service\"".postgres.username="\"$user\" ${GEN3_HELM_MIGRATE_FOLDER}/values.yaml

    fi
}


gen3_helm_values() {
    gen3_log_info "Creating a sample Values.yaml file under ${GEN3_HELM_MIGRATE_FOLDER}/values.yaml"
    cd ${GEN3_HELM_MIGRATE_FOLDER} 
    rm -f values.yaml temp.yaml template.yaml
    cp $GEN3_TEMPLATE_FOLDER/values_template.yaml ${GEN3_HELM_MIGRATE_FOLDER}/template.yaml 
    ( echo "cat <<EOF >values.yaml";
    cat template.yaml;
    echo "EOF";
    ) >temp.yaml

    # Execute this file that has cat <<EOF >values.yaml in it so values.yaml is populated
    . temp.yaml
    gen3_log_info "Validating that generated values.yaml is a valid yaml"
    yq . values.yaml 
    # Remove temporary files. 
    rm temp.yaml template.yaml



    all_services=("ambassador" "arborist" "argo-wrapper" "audit" "aws-es-proxy" "fence" "guppy" "hatchery" "indexd" "manifestservice" "metadata" "peregrine" "pidgin" "portal" "requestor" "revproxy" "sheepdog" "ssjdispatcher" "wts")
    services=$(g3k_manifest_lookup .versions | jq -r keys[])
    diff=()
    for service in $services; do 
        if array_contains "$service" "${all_services[@]}"; then
            gen3_log_info "$service enabled"
            yq -yi "."\"$service\"".enabled=true" ${GEN3_HELM_MIGRATE_FOLDER}/values.yaml

            # TODO: Finish this function
            # gen3_helm_service_creds $service
        else 
            gen3_log_warn "$service disabled. Either there's no helm chart for it yet, or it is not enabled in manifest.json"
            yq -yi "del(."\"$service\"")" ${GEN3_HELM_MIGRATE_FOLDER}/values.yaml
            yq -yi "."\"$service\"".enabled=false" ${GEN3_HELM_MIGRATE_FOLDER}/values.yaml
        fi
    done

    gen3_fence_config
}

gen3_fence_config() {
    gen3_log_info "Generating fence_values.yaml file from fence config"
    local confFile="$(gen3_secrets_folder)/apis_configs/fence-config.yaml"
    rm -f ${GEN3_HELM_MIGRATE_FOLDER}/fence_values.yaml
    touch ${GEN3_HELM_MIGRATE_FOLDER}/fence_values.yaml

    # yq -y '.spec.template.temp.vars[].env += input.env' template1.yaml template2.yaml
    # yq -y '.fence.FENCE_CONFIG += input' ${GEN3_HELM_MIGRATE_FOLDER}/fence_values.yaml ${confFile} 

    yq . $(gen3_secrets_folder)/apis_configs/fence-config.yaml | jq -r '{"fence": { "FENCE_CONFIG": .}}' | yq -y . > ${GEN3_HELM_MIGRATE_FOLDER}/fence_values.yaml

}

gen3_helm_migrate() {
    services=$(g3k_manifest_lookup .versions | jq -r keys[])
    gen3_log_info "Creating folder under ${GEN3_HELM_MIGRATE_FOLDER}/ for database backups."
    gen3_log_warn "Make sure there's enough disk space on adminvm for DB backups."
    mkdir -p ${GEN3_HELM_MIGRATE_FOLDER}

    for service in $services; do
        gen3_helm_dump_db $service
    done

    gen3_helm_values 

    gen3_log_info "Everything seems to work fine. The elasticsearch and pgdumps can be uploaded to s3 and configured for restore."
    gen3_log_info "Try deploying gen3 with helm like this in another namespace to complete migration"
    gen3_log_info "helm upgrade --install <release_name> -f values.yaml -f fence_values.yaml -n <namespace>"


}


gen3_helm_s3_upload() {
    local BUCKET_NAME="$(gen3 api environment)-$(gen3 db namespace)-datadump"
    local ENV=$(gen3 api environment)
    if aws s3api head-bucket --bucket ${BUCKET_NAME}; then
        #// Check if the bucket exists
        echo 'Bucket already exists'
    else
        # Create the bucket if it does not exist
        aws s3api create-bucket --bucket ${BUCKET_NAME} 
        aws s3api put-bucket-versioning --bucket ${BUCKET_NAME} --versioning-configuration Status=Enabled
        echo 'Bucket created'
    fi


    aws s3 cp --recursive ${GEN3_HELM_MIGRATE_FOLDER}/pgdumps/ s3://${BUCKET_NAME}/${ENV}/pgdumps/
    aws s3 cp --recursive ${GEN3_HELM_MIGRATE_FOLDER}/elasticsearch/ s3://${BUCKET_NAME}/${ENV}/elasticsearch/

}

# main -----------------------------

# Support sourcing this file for test suite
if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
    if [[ $# -lt 1 || -z "$1" ]]; then
        gen3 help helm-migrate
    fi
    command="$1"
    shift
    case "$command" in
        "migrate")
            gen3_helm_migrate "$@"
        ;;
        "values")
            gen3_helm_values "$@"
        ;;
        "fence")
            gen3_fence_config "$@"
        ;;
        "s3")
            gen3_helm_s3_upload "$@"
        ;;
        *)
            gen3_db_help
        ;;
    esac
    exit $?
fi


