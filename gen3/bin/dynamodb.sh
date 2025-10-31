#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

gen3_dynamodb_help() {
  gen3 help dynamodb
}

# Used to create backup of tables
gen3_dynamodb_create_backup() {
  # Takes the table prefix qa/internalstaing/etc. as optional positional argument
  local tablePrefix=$1
  local timestamp=$(date -u +%Y%m%d)
  if [[ -z $tablePrefix ]]; then
    # pi_users should be created so use that as a table to check
    tablePrefixes=$(aws dynamodb list-tables | jq -r .TableNames[] | grep pi_users | grep - | rev | cut -d '-' -f 2 | rev)
    if [[ ! -z $tablePrefixes ]]; then
      echo "Are you trying to work with tables that include one of the following prefixes?"
      echo "$tablePrefixes"
      echo "Please input one or press enter and this will proceed on tables without any prefix"
      read tablePrefix
    fi
  fi
  # If there is no table prefix, assume its prod, strip the other tables and then set the backup prefix to include prod
  if [[ -z $tablePrefix ]]; then
    # Find other prefixes and strip those out
    # Get all table names
    tables=$(aws dynamodb list-tables | jq -r .TableNames[])
    # Find other prefixes for multiple ACCESS BACKENDs setup in same account 
    # pi_users should be created so use that as a table to check
    otherPrefixes=$(echo $tables |grep pi_users | grep - | rev | cut -d '-' -f 2 | rev)
    # Format the table prefixes for command to get unprefixed tables
    tablePrefix=$(echo $otherPrefixes | sed 's/ /\\|/g')
    # Grab just unprefixed tables
    tables=$(aws dynamodb list-tables | jq -r .TableNames[] | sed "/^$tablePrefix/d")
    # Use new tables var to create backups postfixed with date
    for table in $tables; do
      # Prepend prod for easy back listing/restoration
      aws dynamodb create-backup --table-name="$table" --backup-name="prod-$table-$timestamp"
    done
    backupList=$(aws dynamodb list-backups | jq -r .BackupSummaries[].BackupName)
    backupsToRestore=$(echo $backupList | grep $prefix-)
    tablePrefix='prod'
  # If there is a table prefix strip the other tables and use the table prefix with the backup creation
  else
    # If tablePrefix is returned just return tables with prefix
    tables=$(aws dynamodb list-tables | jq -r .TableNames[] | grep "$tablePrefix-" )
    for table in $tables; do
      # Do next check to make sure its actual table prefix
      if [[ $table = $tablePrefix* ]]; then
        aws dynamodb create-backup --table-name="$table" --backup-name="$table-$timestamp"
      fi
    done
  fi
}

# Used to list all backups for a prefix
gen3_dynamodb_list_backups() {
  # Takes the table prefix qa/internalstaing/etc. as optional positional argument
  local tablePrefix
  # If postional argument isn't defined get table prefix
  if [[ -z $1 ]]; then
    # pi_users should be created so use that as a table to check
    tablePrefixes=$(aws dynamodb list-tables | jq -r .TableNames[] |grep pi_users | grep - | rev | cut -d '-' -f 2 | rev)
    if [[ ! -z $tablePrefixes ]]; then
      echo "Are you trying to work with tables that include one of the following prefixes?"
      echo "$tablePrefixes"
      echo "Please input one or press enter and this will proceed on tables without any prefix"
      read tablePrefix
    fi
  fi
  # If prefix isn't given at this point, assume it's prod table and set the table prefix to be prod, which is prepended automatically during backup creation
  if [[ -z $tablePrefix ]]; then
    tablePrefix="prod"
  fi
  # Will return list of all backups, need to filter for certain one based on timestamp
  aws dynamodb list-backups | jq -r .BackupSummaries[].BackupName | grep $tablePrefix > $XDG_RUNTIME_DIR/tables
  # Print the table names
  while read line; do
    if [[ $line = $tablePrefix* ]]; then
      echo $line
    fi  
  done<$XDG_RUNTIME_DIR/tables
  rm $XDG_RUNTIME_DIR/tables
}


# Used to restore backups to table
gen3_dynamodb_restore_backup() {
  # Takes the table prefix qa/internalstaing/etc. as optional positional argument
  local tablePrefix=$1
  # If not provided need to get the prefix
  if [[ -z $1 ]]; then
    # pi_users should be created so use that as a table to check
    tablePrefixes=$(aws dynamodb list-tables | jq -r .TableNames[] |grep pi_users | grep - | rev | cut -d '-' -f 2 | rev)
    if [[ ! -z $tablePrefixes ]]; then
      echo "Are you trying to work with tables that include one of the following prefixes?"
      echo "$tablePrefixes"
      echo "Please input one or press enter and this will proceed on tables without any prefix"
      read tablePrefix
    fi
  fi
  # If prefix isnt given at this point, assume it's prod table and set the table prefix to be prod, which is prepended automatically during backup creation
  if [[ -z $tablePrefix ]]; then
    tablePrefix="prod"
  fi
  # Get a list of backups with the prefix to allow users to see the timestamps to pick from and the backups actually created
  aws dynamodb list-backups | jq -r .BackupSummaries[].BackupName | grep $tablePrefix- > $XDG_RUNTIME_DIR/tables
  echo "The possible dates of backups to restore are:" 
  while read line; do
    if [[ $line = $tablePrefix* ]]; then
      # pi_users should be created so use that as a table to check
      echo $line | grep pi_users | rev | cut -d '-' -f 1 | rev
    fi  
  done<$XDG_RUNTIME_DIR/tables
  rm $XDG_RUNTIME_DIR/tables
  echo "Please select a date you would like to restore."
  read timestamp
  if [[ -z $(echo $backupList | grep $timestamp) ]]; then
    echo "Could not find that any backups with that timestamp, please try again"
    return 1
  fi
  # Get the backup arns and table names that have the timestamp and prefix specified
  aws dynamodb list-backups | jq -r '.BackupSummaries[] | "\(.BackupArn) \(.TableName) \(.BackupName) "' | grep $timestamp | grep $tablePrefix > $XDG_RUNTIME_DIR/backups
  # Loop over these, delete the current table, recreate table from backup
  while read -u 3 line; do
    # Get the backupArn and tableNames to restore
    backupArn=$(echo $line | cut -d ' ' -f 1)
    tableName=$(echo $line | cut -d ' ' -f 2)
    # Do a quick check to make sure tables are alright to delete
    gen3_log_info "Are you ready to delete $tableName and recreate from backup. (y/n)"
    read deleteBool
    # Exit script if permission to delete isn't given
    if [[ $deleteBool != "y" ]]; then
      gen3_log_err "You indicated you did not want to delete $tableName. Please rerun later when you are ready to."
      exit 1
    fi
    # Delete table to allow table to be restore with same name
    aws dynamodb delete-table --table-name $tableName
    while [[ ! -z $(aws dynamodb list-tables | grep $tableName) ]]; do
      gen3_log_info "Waiting for $tableName to be deleted"
      sleep 5
    done
    gen3_log_info "Table deleted, restoring from backup now."
    # Restore table from backup to original table name
    aws dynamodb restore-table-from-backup --target-table-name $tableName --backup-arn $backupArn
  done 3<$XDG_RUNTIME_DIR/backups
  rm $XDG_RUNTIME_DIR/backups
}

# main -----------------------------

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then

  command="$1"
  shift
  case "$command" in
    "create-backup")
      gen3_dynamodb_create_backup "$@"
      ;;
    "list-backups")
      gen3_dynamodb_list_backups "$@";
      ;;
    "restore")
      gen3_dynamodb_restore_backup "$@";
      ;;     
    *)
      gen3_dynamodb_help
      ;;
  esac
  exit $?
fi
