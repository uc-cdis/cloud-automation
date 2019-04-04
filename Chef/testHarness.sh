#!/bin/bash

if [[ ! -f ./installClient.sh ]]; then
  echo "ERROR: must run in misc-stuff/Chef folder"
  exit 1
fi

# 
# Pass args through to docker run - 
#   ex: bash testHarness.sh --rm to auto-delete container
#
docker run -it -v "$(pwd):/mnt/chefRepo" -v /var/run/docker.sock:/var/run/docker.sock --workdir=/mnt/chefRepo --name=chefTest "$@" ubuntu:18.04
