#!/bin/bash
#
# Terraform template concatenated with kube-services.sh and kube-up.sh in kube.tf
#

set -e

export vpc_name='${vpc_name}'
export s3_bucket='${s3_bucket}'
