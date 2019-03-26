#!/bin/bash

if [[ ! -f ./installClient.sh ]]; then
  echo "ERROR: must run in misc-stuff/Chef folder"
  exit 1
fi

# 
# Pass args through to docker run - 
#   ex: bash testHarness.sh --rm to auto-delete container
#
docker run -it -v "$(pwd):/mnt/chefRepo" --workdir=/mnt/chefRepo --name=chefTest "$@" ubuntu:18.04