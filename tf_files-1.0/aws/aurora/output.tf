##
# aws_rds_aurora_cluster
##

output "aurora_cluster_writer_endpoint" {
  description = "Aurora cluster writer instance endpoint"
  value       = module.aurora[0].aurora_cluster_writer_endpoint
}

output "aurora_cluster_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = module.aurora[0].aurora_cluster_reader_endpoint
}


output "aurora_cluster_master_username" {
  description = "Aurora cluster master username"
  value       = module.aurora[0].aurora_cluster_master_username
}

output "aurora_cluster_master_password" {
  description = "Aurora cluster master user's password"
  value       = module.aurora[0].aurora_cluster_master_password
  sensitive   = true
}
