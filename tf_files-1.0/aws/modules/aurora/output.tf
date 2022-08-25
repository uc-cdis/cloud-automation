##
# aws_rds_aurora_cluster
##

output "aurora_cluster_writer_endpoint" {
  description = "Aurora cluster writer instance endpoint"
  value       = aws_rds_cluster.postgresql.endpoint
}

output "aurora_cluster_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = aws_rds_cluster.postgresql.reader_endpoint
}


output "aurora_cluster_master_username" {
  description = "Aurora cluster master username"
  value       = aws_rds_cluster.postgresql.master_username
}

output "aurora_cluster_master_password" {
  description = "Aurora cluster master user's password"
  value       = aws_rds_cluster.postgresql.master_password
  sensitive  = true
}
