
output "rds_endpoint" {
  value = module.db.this_db_instance_endpoint
}

output "rds_user" {
  value = module.db.this_db_instance_username
}

output "rds_password" {
  value = module.db.this_db_instance_password
}

output "output_bucket" {
  value = aws_s3_bucket.data_bucket.id
}
