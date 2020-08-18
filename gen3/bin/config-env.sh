#!/bin/bash
#
# This script will copy the environment configuration of the specified environment or apply
# version updates to all the services and may specify particular values for a given subset of services.
# It is designed to be used in Dev or QA virtual machines.
#
# gen3 config-env copy {repo} {environment}
# repo = The Github repository where the environment is located
# environment = The Gen3 environment to be copied

# gen3 config-env apply {version} {override} 
# version = The version of services desired
# override = (optional) Json-formatted string for assigning versions to specific services 

# Example usage: 
# gen3 config-env copy cdis-manifest gen3.theanvil.io
# gen3 config-env apply 2020.09 
# gen3 config-env apply 2020.09 {"ambassador":"quay.io/datawire/ambassador:2020.11"}

source ${GEN3_HOME}/gen3/lib/utils.sh

tgt_env=~/cdis-manifest/${USER}.planx-pla.net

if [[ "$1" == "copy" ]]; then
        git clone https://github.com/uc-cdis/${2}.git ~/temp_manifest
        if [[ $? != 0 ]]; then
                gen3_log_err "Something went wrong with getting source env check arguments\n Attempted to clone https://github.com/uc-cdis/${2}.git"
                return 1
        fi
        srcenv=~/temp_manifest/$3
        cmd="copy -s ${srcenv} -e ${tgt_env}"
        
# Assumes positional arguments apply {version} {overide}
elif [[ "$1" == "apply" ]]; then
        if [[ $# == 2 ]]; then 
                cmd="$1 -v $2 -e ${tgt_env}"
        # if the optional {override} param specified
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
