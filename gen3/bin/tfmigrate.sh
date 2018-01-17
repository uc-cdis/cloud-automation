help() {
  cat - <<EOM
  gen3 tfmigrate:
    Update the terraform state in the current workspace via a series of 'terraform state mv' commands
    after backing up the current terraform.tfstate to terraform.tfstate.bak.md5sum.
    Be sure to run this command with '--dryrun' first to see what changes will be scheduled.
EOM
  return 0
}

if [[ ! -f "$GEN3_HOME/gen3/lib/common.sh" ]]; then
  echo "ERROR: no $GEN3_HOME/gen3/lib/common.sh"
  exit 1
fi

source "$GEN3_HOME/gen3/lib/common.sh"

cd $GEN3_WORKDIR

declare -a renameDb
renameDb=(
  "aws_vpc.main"
  "aws_vpc_endpoint.private-s3"
  "aws_internet_gateway.gw"
  "aws_route_table.public"
  "aws_eip.login"
  "aws_eip_association.login_eip"
  "aws_route_table.private_user"
  "aws_route_table_association.public"
  "aws_route_table_association.private_user"
  "aws_subnet.public"
  "aws_subnet.private_user"
  "aws_ami_copy.login_ami"
  "aws_ami_copy.squid_ami"
  "aws_instance.login"
  "aws_instance.proxy"
  "aws_route53_zone.main"
  "aws_route53_record.squid"
  "aws_security_group.ssh"
  "aws_security_group.login-ssh"
  "aws_security_group.local"
  "aws_security_group.webservice"
  "aws_security_group.out"
  "aws_security_group.proxy"
)

DRYRUN=""
if $GEN3_DRY_RUN; then
  DRYRUN="--dryrun"
fi

s3Source="s3://$GEN3_S3_BUCKET/${GEN3_VPC}/terraform.tfstate"
s3Dest="s3://$GEN3_S3_BUCKET/${GEN3_VPC}/terraform.tfstate.bak"
echo "Backing up terraform state from $s3Source to $s3Dest"

if ! aws s3 cp $DRYRUN "$s3Source" "$s3Dest"; then
  echo "ERROR: backup failed - bailing out without migrating terraform state"
  exit 1
fi

for oldName in "${renameDb[@]}"; do 
  echo $oldName
  newName="module.cdis_vpc.${oldName}"
  echo "$DRYRUN terraform state mv $oldName $newName"
  $GEN3_DRY_RUN && terraform state mv "$oldName" "$newName"
done
