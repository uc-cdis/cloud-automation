output "rds_instance_username" {
  value = module.aws_rds.rds_instance_username
}

output "rds_instance_password" {
  value     = module.aws_rds.rds_instance_password
  sensitive = true
}

output "rds_instance_endpoint" {
  value = module.aws_rds.rds_instance_endpoint
}

output "rds_instance_arn" {
  value = module.aws_rds.rds_instance_arn
}
