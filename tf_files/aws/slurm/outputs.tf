
output "rds_endpoint" {
  value = module.db.this_db_instance_endpoint
}

output "rds_user" {
  value = module.db.this_db_instance_username
}

output "rds_password" {
  value = module.db.this_db_instance_password
}
