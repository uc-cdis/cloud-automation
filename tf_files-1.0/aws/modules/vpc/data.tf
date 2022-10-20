data "aws_region" "current" {}

data "aws_availability_zones" "available" {}

data "aws_caller_identity" "current" {}

data "aws_route_tables" "control_routing_table" {
  count   = var.csoc_managed ? 0 : 1
  vpc_id  = var.peering_vpc_id
}
