#!/bin/bash

# Script Name: config-update.sh
# Description: This script updates the gen3 config files for various services based on information 
#              provided in a migration file migration.txt. It updates JSON configuration files and other related files 
#              with new database host, username, and database name. The script also verifies the updates 
#              to ensure they are applied correctly.

# Ensure the GEN3_HOME variable is set to the correct path
if [[ -z "$GEN3_HOME" ]]; then
  echo "GEN3_HOME is not set. Please set it to the path of your Gen3 installation."
  exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  echo "jq could not be found. Please install jq to run this script."
  exit 1
fi

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

# Backup the $HOME/Gen3Secrets directory
backup_dir="$HOME/Gen3Secrets-$(date +%Y%m%d%H%M%S)"
cp -r "$HOME/Gen3Secrets" "$backup_dir"
echo "Backup of Gen3Secrets created at $backup_dir"

# Function to update JSON file
update_json_config() {
    local file_path=$1
    local service=$2
    local db_host=$3
    local db_username=$4
    local db_database=$5

    echo "Updating JSON config for service: $service"
    echo "File path: $file_path"
    echo "db_host: $db_host"
    echo "db_username: $db_username"
    echo "db_database: $db_database"

    if [[ -f $file_path ]]; then
        local tmp_file
        tmp_file=$(mktemp)

        if [[ $service == "fence" || $service == "userapi" ]]; then
            jq --arg db_host "$db_host" --arg db_username "$db_username" --arg db_database "$db_database" \
               '(.fence.db_host = $db_host) | (.fence.db_username = $db_username) | (.fence.db_database = $db_database) |
                (.fence.fence_database = $db_database) |
                (.userapi.db_host = $db_host) | (.userapi.db_username = $db_username) | (.userapi.db_database = $db_database) |
                (.userapi.fence_database = $db_database) |
                (.sheepdog.fence_host = $db_host) | (.sheepdog.fence_username = $db_username) | (.sheepdog.fence_database = $db_database) |
                (.gdcapi.fence_host = $db_host) | (.gdcapi.fence_username = $db_username) | (.gdcapi.fence_database = $db_database) |
                (.peregrine.fence_host = $db_host) | (.peregrine.fence_username = $db_username) | (.peregrine.fence_database = $db_database)' \
               "$file_path" > "$tmp_file" && mv "$tmp_file" "$file_path"

            # Verify the update
            local updated_host updated_username updated_database
            updated_host=$(jq -r '.fence.db_host' "$file_path")
            updated_username=$(jq -r '.fence.db_username' "$file_path")
            updated_database=$(jq -r '.fence.db_database' "$file_path")
            if [[ "$updated_host" == "$db_host" && "$updated_username" == "$db_username" && "$updated_database" == "$db_database" ]]; then
                gen3_log_info "Updated JSON config for service: $service successfully."
            else
                gen3_log_err "Failed to update JSON config for service: $service."
            fi

        elif [[ $service == "sheepdog" || $service == "gdcapi" ]]; then
            jq --arg db_host "$db_host" --arg db_username "$db_username" --arg db_database "$db_database" \
               '(.sheepdog.db_host = $db_host) | (.sheepdog.db_username = $db_username) | (.sheepdog.db_database = $db_database) |
                (.gdcapi.db_host = $db_host) | (.gdcapi.db_username = $db_username) | (.gdcapi.db_database = $db_database)' \
               "$file_path" > "$tmp_file" && mv "$tmp_file" "$file_path"

            # Verify the update
            local updated_host updated_username updated_database
            updated_host=$(jq -r '.sheepdog.db_host' "$file_path")
            updated_username=$(jq -r '.sheepdog.db_username' "$file_path")
            updated_database=$(jq -r '.sheepdog.db_database' "$file_path")
            if [[ "$updated_host" == "$db_host" && "$updated_username" == "$db_username" && "$updated_database" == "$db_database" ]]; then
                gen3_log_info "Updated JSON config for service: $service successfully."
            else
                gen3_log_err "Failed to update JSON config for service: $service."
            fi

        elif [[ $service == "indexd" ]]; then
            jq --arg db_host "$db_host" --arg db_username "$db_username" --arg db_database "$db_database" \
               '(.indexd.db_host = $db_host) | (.indexd.db_username = $db_username) | (.indexd.db_database = $db_database)' \
               "$file_path" > "$tmp_file" && mv "$tmp_file" "$file_path"

            # Verify the update
            local updated_host updated_username updated_database
            updated_host=$(jq -r '.indexd.db_host' "$file_path")
            updated_username=$(jq -r '.indexd.db_username' "$file_path")
            updated_database=$(jq -r '.indexd.db_database' "$file_path")
            if [[ "$updated_host" == "$db_host" && "$updated_username" == "$db_username" && "$updated_database" == "$db_database" ]]; then
                gen3_log_info "Updated JSON config for service: $service successfully."
            else
                gen3_log_err "Failed to update JSON config for service: $service."
            fi

        elif [[ $service == "peregrine" ]]; then
            jq --arg db_host "$db_host" --arg db_username "$db_username" --arg db_database "$db_database" \
               '(.peregrine.db_host = $db_host) | (.peregrine.db_username = $db_username) | (.peregrine.db_database = $db_database)' \
               "$file_path" > "$tmp_file" && mv "$tmp_file" "$file_path"

            # Verify the update
            local updated_host updated_username updated_database
            updated_host=$(jq -r '.peregrine.db_host' "$file_path")
            updated_username=$(jq -r '.peregrine.db_username' "$file_path")
            updated_database=$(jq -r '.peregrine.db_database' "$file_path")
            if [[ "$updated_host" == "$db_host" && "$updated_username" == "$db_username" && "$updated_database" == "$db_database" ]]; then
                gen3_log_info "Updated JSON config for service: $service successfully."
            else
                gen3_log_err "Failed to update JSON config for service: $service."
            fi

        else
            jq --arg db_host "$db_host" --arg db_username "$db_username" --arg db_database "$db_database" \
               '(.db_host = $db_host) | (.db_username = $db_username) | (.db_database = $db_database)' \
               "$file_path" > "$tmp_file" && mv "$tmp_file" "$file_path"

            # Verify the update
            local updated_host updated_username updated_database
            updated_host=$(jq -r '.db_host' "$file_path")
            updated_username=$(jq -r '.db_username' "$file_path")
            updated_database=$(jq -r '.db_database' "$file_path")
            if [[ "$updated_host" == "$db_host" && "$updated_username" == "$db_username" && "$updated_database" == "$db_database" ]]; then
                gen3_log_info "Updated JSON config for service: $service successfully."
            else
                gen3_log_err "Failed to update JSON config for service: $service."
            fi
        fi
    else
        echo "File $file_path does not exist."
    fi
}

# Function to update other files
update_other_files() {
    local file_path=$1
    local db_host=$2
    local db_username=$3
    local db_database=$4

    echo "Updating other files at $file_path"
    echo "db_host: $db_host"
    echo "db_username: $db_username"
    echo "db_database: $db_database"

    if [[ -f $file_path ]]; then
        if [[ "$file_path" == *".env" ]]; then
            sed -i "s|DB_HOST=.*|DB_HOST=$db_host|" "$file_path"
            sed -i "s|DB_USER=.*|DB_USER=$db_username|" "$file_path"
            sed -i "s|DB_DATABASE=.*|DB_DATABASE=$db_database|" "$file_path"

            # Verify the update
            local updated_host updated_username updated_database
            updated_host=$(grep 'DB_HOST=' "$file_path" | cut -d'=' -f2)
            updated_username=$(grep 'DB_USER=' "$file_path" | cut -d'=' -f2)
            updated_database=$(grep 'DB_DATABASE=' "$file_path" | cut -d'=' -f2)
        else
            sed -i "s|DB_HOST:.*|DB_HOST: $db_host|" "$file_path"
            sed -i "s|DB_USER:.*|DB_USER: $db_username|" "$file_path"
            sed -i "s|DB_DATABASE:.*|DB_DATABASE: $db_database|" "$file_path"

            # Verify the update
            local updated_host updated_username updated_database
            updated_host=$(grep 'DB_HOST:' "$file_path" | cut -d':' -f2 | xargs)
            updated_username=$(grep 'DB_USER:' "$file_path" | cut -d':' -f2 | xargs)
            updated_database=$(grep 'DB_DATABASE:' "$file_path" | cut -d':' -f2 | xargs)
        fi

        if [[ "$updated_host" == "$db_host" && "$updated_username" == "$db_username" && "$updated_database" == "$db_database" ]]; then
            gen3_log_info "Updated file at $file_path successfully."
        else
            gen3_log_err "Failed to update file at $file_path."
        fi
    else
        echo "File $file_path does not exist."
    fi
}

# Function to update fence-config.yaml
update_fence_config() {
    local creds_json_path="$HOME/Gen3Secrets/creds.json"
    local file_path=$1
    local db_host=$2
    local db_username=$3
    local db_database=$4

    echo "Updating fence-config.yaml at $file_path"
    echo "db_host: $db_host"
    echo "db_username: $db_username"
    echo "db_database: $db_database"

    if [[ -f $file_path ]]; then
        local current_password
        current_password=$(jq -r '.fence.db_password' "$creds_json_path")

        sed -i "s|DB: postgresql://.*:.*@.*:5432/.*|DB: postgresql://$db_username:$current_password@$db_host:5432/$db_database|" "$file_path"

        # Verify the update
        local updated_entry
        updated_entry=$(grep 'DB: postgresql://' "$file_path")
        if [[ "$updated_entry" == *"$db_host"* && "$updated_entry" == *"$db_username"* && "$updated_entry" == *"$db_database"* ]]; then
            gen3_log_info "Updated fence-config.yaml at $file_path successfully."
        else
            gen3_log_err "Failed to update fence-config.yaml at $file_path."
        fi
    else
        echo "File $file_path does not exist."
    fi
}

# Function to parse the migration file and apply updates
parse_and_update() {
    local migration_file=$1
    local creds_json_path="$HOME/Gen3Secrets/creds.json"
    local namespace
    namespace=$(gen3 db namespace)
    local new_db_host
    new_db_host=$(grep "INFO" "$migration_file" | awk '{print $8}')

    gen3_log_info "New db_host identified: $new_db_host"
    while read -r line; do
        if [[ $line == Source_Database* || $line == User* ]]; then
            echo "Processing line: $line"

            IFS=' ' read -r -a parts <<< "$line"
            local db_host="$new_db_host"
            local db_username
            local db_database

            if [[ $line == Source_Database* ]]; then
                db_username="${parts[9]}"
                echo "db_username='${parts[9]}'"
                db_database="${parts[7]}"
                echo "db_database='${parts[7]}'"
            elif [[ $line == User* ]]; then
                db_username="${parts[1]}"
                echo "db_username='${parts[1]}'"
                db_database="${parts[7]}"
                echo "db_database='${parts[7]}'"
            else
                continue
            fi

            # Extract the service name from db_username
            if [[ $db_username =~ ^([a-zA-Z]+)_user_ ]]; then
                local service="${BASH_REMATCH[1]}"
            else
                echo "Skipping line: $line due to improper db_username format"
                continue
            fi

            gen3_log_info "Updating service: $service with db_username: $db_username and db_database: $db_database"

            # Update specific config files for each service
            case $service in
                arborist)
                    update_json_config "$HOME/Gen3Secrets/g3auto/arborist/dbcreds.json" "$service" "$db_host" "$db_username" "$db_database"
                    ;;
                audit)
                    update_json_config "$HOME/Gen3Secrets/g3auto/audit/dbcreds.json" "$service" "$db_host" "$db_username" "$db_database"
                    update_other_files "$HOME/Gen3Secrets/g3auto/audit/audit-service-config.yaml" "$db_host" "$db_username" "$db_database"
                    ;;
                metadata)
                    update_json_config "$HOME/Gen3Secrets/g3auto/metadata/dbcreds.json" "$service" "$db_host" "$db_username" "$db_database"
                    update_other_files "$HOME/Gen3Secrets/g3auto/metadata/metadata.env" "$db_host" "$db_username" "$db_database"
                    ;;
                ohdsi)
                    update_json_config "$HOME/Gen3Secrets/g3auto/ohdsi/dbcreds.json" "$service" "$db_host" "$db_username" "$db_database"
                    ;;
                orthanc)
                    update_json_config "$HOME/Gen3Secrets/g3auto/orthanc/dbcreds.json" "$service" "$db_host" "$db_username" "$db_database"
                    ;;
                requestor)
                    update_json_config "$HOME/Gen3Secrets/g3auto/requestor/dbcreds.json" "$service" "$db_host" "$db_username" "$db_database"
                    update_other_files "$HOME/Gen3Secrets/g3auto/requestor/requestor-config.yaml" "$db_host" "$db_username" "$db_database"
                    ;;
                wts)
                    update_json_config "$HOME/Gen3Secrets/g3auto/wts/dbcreds.json" "$service" "$db_host" "$db_username" "$db_database"
                    ;;
                fence)
                    update_fence_config "$HOME/Gen3Secrets/apis_configs/fence-config.yaml" "$db_host" "$db_username" "$db_database"
                    update_json_config "$creds_json_path" "$service" "$db_host" "$db_username" "$db_database"
                    ;;
                sheepdog | peregrine | indexd)
                    update_json_config "$creds_json_path" "$service" "$db_host" "$db_username" "$db_database"
                    ;;
            esac
        fi
    done < "$migration_file"
}

# Run the script
parse_and_update "migration.txt"
