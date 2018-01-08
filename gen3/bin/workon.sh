
if [[ -z "$GEN3_PROFILE" || -z "$GEN3_VPC" || -z "$GEN3_WORKDIR" ]]; then
  echo "Must define runtime environment: GEN3_PROFILE, GEN3_VPC, GEN3_WORKDIR"
  exit 1
fi

#
# This folder holds secrets, so lock it down permissions wise ...
#
umask 0077
mkdir -p -m 0700 "$GEN3_WORKDIR"

#
# Create any missing files
#

#
# aws_provider.tfvars - this has the secret keys that
# the terraform aws provider wants:
#     https://www.terraform.io/docs/providers/aws/
#
if [[ ! -f "$GEN3_WORKDIR/aws_provider.tfvars" ]]; then
  echo "Creting aws_provider.tfvars"
  cat - > "$GEN3_WORKDIR/aws_provider.tfvars" <<EOM
aws_access_key = "$(aws configure get "$GEN3_PROFILE.aws_access_key_id")"
aws_secret_key = "$(aws configure get "$GEN3_PROFILE.aws_secret_access_key")"
aws_region = "$(aws configure get "$GEN3_PROFILE.region")"
EOM
fi

#
# aws_backend.tfvars - this has the secret keys that
# the terraform S3 backend wants:
#     https://www.terraform.io/docs/backends/types/s3.html
#
if [[ ! -f "$GEN3_WORKDIR/aws_backend.tfvars" ]]; then
  echo "Creting aws_backend.tfvars"
  cat - > "$GEN3_WORKDIR/aws_backend.tfvars" <<EOM
access_key = "$(aws configure get "$GEN3_PROFILE.aws_access_key_id")"
secret_key = "$(aws configure get "$GEN3_PROFILE.aws_secret_access_key")"
region = "$(aws configure get "$GEN3_PROFILE.region")"
EOM
fi


  