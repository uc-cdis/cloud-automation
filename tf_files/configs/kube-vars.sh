#!/bin/bash

#
# Terraform template concatenated with kube-services.sh and kube-up.sh in kube.tf
#
set -e

vpc_name='${vpc_name}'
userapi_snapshot='${userapi_snapshot}'
s3_bucket='${s3_bucket}'
gdcapi_snapshot='${gdcapi_snapshot}'
service_list=(indexd portal sheepdog peregrine)