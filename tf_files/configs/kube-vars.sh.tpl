#!/bin/bash
#
# Terraform template concatenated with kube-services.sh and kube-up.sh in kube.tf
#

set -e

vpc_name='${vpc_name}'
s3_bucket='${s3_bucket}'
fence_snapshot='${fence_snapshot}'
gdcapi_snapshot='${gdcapi_snapshot}'
