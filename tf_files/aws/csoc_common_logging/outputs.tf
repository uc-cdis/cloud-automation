output "cloudwatch_log_group" {
 value = "${module.logging.cloudwatch_log_group}"
}

output "s3_bucket" {
  value = "${module.logging.s3_bucket}"
}

output "log_destination" {
  value = "${module.logging.log_destination}"
}
