#!/bin/bash
#
#backup fake data from db into local postgres for testing
source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

#Copy the pg dump files
aws s3 cp s3://gen3-dummy-data/dbindexd.backup .

#Backup the dbs from the dump files
psql -h postgres-postgresql.postgres.svc.cluster.local -d indexd -U indexd -f dbindexd.backup

rm db*