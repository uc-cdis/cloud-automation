#!/bin/bash
#
# This script will copy the environment configuration of the specified environment or apply
# version updates to all the services and may specify particular values for a given subset of services

source ${GEN3_HOME}/gen3/lib/utils.sh

tgt_env=~/cdis-manifest/${USER}.planx-pla.net

if [[ "$1" == "copy" ]]; then
                git clone https://github.com/uc-cdis/${2}.git ~/temp_manifest
                if [[ $? != 0 ]]; then
        gen3_log_err "Something went wrong with getting source env check arguments"
        return 1
        fi
        srcenv=~/temp_manifest/$3
        cmd="copy -s ${srcenv} -e ${tgt_env}"
        
elif [[ "$1" == "apply" ]]; then
        # Assumes positional arguments apply -v {version} -o {override}
        if [[ $# == 2 ]]; then 
                cmd="$1 -v $2 -e ${tgt_env}"
        else
                cmd="$1 -v $2 -o $3 -e ${tgt_env}"
        fi
else
        gen3_log_err "only apply and copy functions supported"
        return 1
fi

if [[ -e ~/gen3release ]]; then
        git -C ~/gen3release checkout master
        git -C ~/gen3release pull
else
git clone https://github.com/uc-cdis/gen3-release-utils.git ~/gen3release
fi

cd ~/gen3release/gen3release-sdk
python3 -m pip install poetry
poetry install
poetry run gen3release ${cmd}
check_error=$?
if [[ "$1" == "copy" ]]; then
        yes | rm -r ~/temp_manifest
fi
if [[ $check_error != 0 ]]; then
        gen3_log_err "Something went wrong in gen3release script, exited with code $check_error"
        return 1
fi

cd $tgt_env
git add *
set -- 
source ${GEN3_HOME}/gen3/bin/roll.sh
gen3 roll all 
