#!/bin/bash
# 
# Little helper to deploy the k8s resources around
# the useryaml cron job in the correct order.
#
# Assumes this runs in the same directory as the .yaml files
#

set -e

declare -a yamlList

yamlList=(
  ../jenkins/role-devops.yaml
  ./useryaml-serviceaccount.yaml
  ./useryaml-rolebinding.yaml
  ./useryaml-cronjob.yaml
)

for path in "${yamlList[@]}"; do
  if [[ ! -f "$path" ]]; then
    echo "ERROR: no such file: $path"
    exit 1
  fi
done

for path in "${yamlList[@]}"; do
  kubectl apply -f "$path"
done
