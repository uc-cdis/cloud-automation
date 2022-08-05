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

output "sheepdog_rds_id" {
  value = aws_db_instance.db_sheepdog.*.id
}

output "fence-bot_user_secret" {
  value     = module.cdis_vpc.fence-bot_secret
  sensitive = true
}

output "fence-bot_user_id" {
  value = module.cdis_vpc.fence-bot_id
}

output "data-bucket_name" {
  value = module.cdis_vpc.data-bucket_name
}

output "kubeconfig" {
  value = module.eks[0].kubeconfig
}

output "config_map_aws_auth" {
  value = module.eks[0].config_map_aws_auth
}
