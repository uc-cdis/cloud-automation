data "aws_availability_zones" "available" {}

data "aws_vpc" "csoc_vpc" {
  count = "${var.csoc_managed == "yes" ? 0 : 1}"
  id    = "${var.csoc_vpc_id}"
}

#data "aws_vpc_endpoint_service" "s3" {
#  service = "s3"
#}
