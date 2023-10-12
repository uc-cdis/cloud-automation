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
  value = aws_db_instance.db_indexd.*.identifier
}

output "fence_rds_id" {
  value = aws_db_instance.db_fence.*.identifier
}

output "sheepdog_rds_id" {
  value = aws_db_instance.db_sheepdog.*.identifier
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
  sensitive   = true  
}

output "config_map_aws_auth" {
  value = module.eks[0].config_map_aws_auth
  sensitive   = true  
}

##
# aws_rds_aurora_cluster
##

output "aurora_cluster_writer_endpoint" {
  description = "Aurora cluster writer instance endpoint"
  value       = one(module.aurora[*].aurora_cluster_writer_endpoint)
}

output "aurora_cluster_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = one(module.aurora[*].aurora_cluster_reader_endpoint)
}


output "aurora_cluster_master_username" {
  description = "Aurora cluster master username"
  value       = one(module.aurora[*].aurora_cluster_master_username)
}

output "aurora_cluster_master_password" {
  description = "Aurora cluster master user's password"
  value       = one(module.aurora[*].aurora_cluster_master_password)
  sensitive   = true
}
