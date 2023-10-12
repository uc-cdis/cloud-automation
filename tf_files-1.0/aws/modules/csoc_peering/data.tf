data "aws_route_table" "selected" {
  filter {
    name   = "tag:Name"
    values = [var.route_table_name]
  }
  vpc_id = var.csoc_vpc_id
}