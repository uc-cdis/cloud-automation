#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

userEmail="$1"
shift
directoryID="$1"
shift
hostname="$1"

if [[ -z "$userEmail" ]]; then
	echo -e "Use: gen3 cedar-register user-email directory hostname" 1>&2
	exit 1
fi

if [[ -z "$directoryID" ]]; then
	echo -e "Use: gen3 cedar-register user-email directory hostname" 1>&2
	exit 1
fi

if [[ -z "$hostname" ]]; then
	echo -e "Use: gen3 cedar-register user-email directory hostname" 1>&2
	exit 1
fi


accessToken=$(gen3 api access-token "$userEmail") 
export GEN3_HOME="${GEN3_HOME:-"$HOME/cloud-automation"}"

python ${GEN3_HOME}/files/scripts/healdata/heal-cedar-data-ingest.py --access_token $accessToken --directory $directoryID --hostname $hostname
