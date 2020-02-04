#!/bin/bash -e

set -e
cd "$(dirname $0)"

function usage() {
  cat << ENDOFM
bash buildAll.sh [variableFile.json]
    ex: bash buildAll.sh ~/.gen3/secrets/packer/cdistest.json
where cdistest.json looks like:
{
    "aws_region": "us-east-1",
    "aws_instance_type": "m4.xlarge",
    "aws_access_key": "YOUR KEY",
    "aws_secret_key": "YOUR SECRET"
}
ENDOFM
}

# override by command-line
PACKER_VARIABLES="variables.json"

if [ "$#" != "0" ]; then
  PACKER_VARIABLES=$1
fi

if [ ! -f "${PACKER_VARIABLES}" ]; then
    echo "json file defining variables for packer does not exist: ${PACKER_VARIABLES}"
    echo "check README.md"
    usage
    exit 1
fi


function packer_build_image() {
    #
    # Stole this from the cloud-automation repo.
    # Attempt to build the image file $1 using packer. If this runs into errors,
    # print the error output from packer and exit 1. Otherwise, return the ID of
    # the Amazon Machine Image (AMI) built.
    #
    packer_output="$(packer build --var-file $PACKER_VARIABLES -machine-readable images/$1)"
    #packer_output=bla
    packer_errors="$(echo "$packer_output" | egrep '^.*,.*,.*,error' | cut -d ',' -f 5-)"
    if [[ -n $packer_errors ]]; then
        echo "packer failed to build image: $1" >&2
        echo -e "$packer_errors" >&2
        exit 1
    fi
    echo "$packer_output" | egrep 'artifact,0,id' | rev | cut -d ',' -f 1 | rev | cut -d ':' -f 2
}

if [ -z "$UBUNTU_BASE" ]; then
  echo "Building packer ubuntu16_base image"
  UBUNTU_BASE="$(packer_build_image ubuntu16_base.json)"
  [ $? == 1 ] && exit 1;
  echo "ubuntu16_base ami is $UBUNTU_BASE"
  export ub16_source_ami="$UBUNTU_BASE"
fi

if [ -z "$UBUNTU_CLIENT" ]; then
  echo "Building packer ubuntu16_client image"
  UBUNTU_CLIENT="$(packer_build_image ubuntu16_client.json)"
  [ $? == 1 ] && exit 1;
  echo "ubuntu16_client ami is $UBUNTU_CLIENT"
fi


if [ -z "$UBUNTU_PROXY" ]; then
  echo "Building packer ubuntu16_squid image"
  UBUNTU_PROXY="$(packer_build_image ubuntu16_squid.json)"
  [ $? == 1 ] && exit 1;
  echo "ubuntu16_squid ami is $UBUNTU_PROXY"
fi

cat > source.json << EOM
{
  "UBUNTU_BASE":"${UBUNTU_BASE}",
  "UBUNTU_CLIENT":"${UBUNTU_CLIENT}",
  "UBUNTU_PROXY":"${UBUNTU_PROXY}"
}
EOM

