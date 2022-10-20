variable "bucket_name"{
  # this variable is required in config.tfvars
}

#
# AWS only allows one bucket notification config per bucket,
# so don't do this if the bucket already has a notification
# configured
#
variable "configure_bucket_notifications" {
  default = true
}