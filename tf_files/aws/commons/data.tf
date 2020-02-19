data "aws_availability_zones" "available" {}

data "aws_vpc" "csoc_vpc" {
  count = "${var.csoc_managed ? 0 : 1}"
  id    = "${var.peering_vpc_id}"
}
