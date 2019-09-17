
output "rds_instance_username" {
  value = "${aws_db_instance.rds_instance.username}"
}

output "rds_instance_password" {
  value = "${aws_db_instance.rds_instance.password}"
}

output "rds_instance_endpoint" {
  value = "${aws_db_instance.rds_instance.endpoint}"
}

output "rds_instance_arn" {
  value = "${aws_db_instance.rds_instance.arn}"
}
