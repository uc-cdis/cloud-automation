#
# Trying to move toward a model where terraform
# outputs all variables necessary for subsequent
# post-terraform devops.
# We then work like this:
#    terraform output -json > "${vpcname}.json"
# , and subsequent automation scripts consume ${vpcname}.json
# as an input.
#

output "aws_region" {
  value = var.aws_region
}

output "vpc_name" {
  value = var.vpc_name
}

output "vpc_cidr_block" {
  value = module.cdis_vpc.vpc_cidr_block
}

output "indexd_rds_id" {
  value = aws_db_instance.db_indexd.*.id
}

output "fence_rds_id" {
  value = aws_db_instance.db_fence.*.id
}

output "gdcapi_rds_id" {
  value = aws_db_instance.db_gdcapi.*.id
}

output "fence-bot_user_secret" {
  value = module.cdis_vpc.fence-bot_secret
}

output "fence-bot_user_id" {
  value = module.cdis_vpc.fence-bot_id
}

output "data-bucket_name" {
  value = module.cdis_vpc.data-bucket_name
}
