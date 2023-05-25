#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


# Default bucket name
accountId=$(aws sts get-caller-identity --query "Account" --output text)
DEFAULT_BUCKET_NAME="gen3-db-backups-${accountId}"
# Default databases
DEFAULT_DATABASES=("indexd" "sheepdog" "metadata")
S3_DIR="$(date +"%Y-%m-%d-%H-%M-%S")"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --databases)
            DATABASES=(${2//,/ })
            shift # past argument
            shift # past value
            ;;
        --s3-bucket)
            BUCKET_NAME="$2"
            shift # past argument
            shift # past value
            ;;
        *) # unknown option
            shift # past argument
            ;;
    esac
done

# Set default values for missing variables
if [[ -z $DATABASES ]]; then
    DATABASES=("${DEFAULT_DATABASES[@]}")
fi

if [[ -z $BUCKET_NAME ]]; then
    BUCKET_NAME=$DEFAULT_BUCKET_NAME
fi

# Backup databases and upload to S3 bucket
for database in "${DATABASES[@]}"; do
    echo "Starting database backup for ${database}"
    gen3 db backup "${database}" > "${database}.sql"
    echo "Uploading backup file ${database}.sql to s3://${BUCKET_NAME}/${S3_DIR}/${database}.sql"
    aws s3 cp "${database}.sql" "s3://${BUCKET_NAME}/${S3_DIR}/${database}.sql"
    echo "deleting temporary backup file ${database}.sql"
done

