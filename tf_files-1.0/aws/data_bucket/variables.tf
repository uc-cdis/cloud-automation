variable "bucket_name" {}

variable "environment" {
  # value for 'Environment' key to tag the new resources with 
}
variable "cloud_trail_count" {
  # this variable is used to conditionally create a cloud trail
  # Using this module to create another bucket in the same "environment" with nonzero
  # count for this variable will result in an error because aspects of the cloud trail 
  # will already exist
  default = "1"
  description = "Number of cloud trails to create - Limited to 5 trails per region"
}
