# this is for vpc peering
resource "aws_vpc_peering_connection_accepter" "vpcpeering" {
  vpc_peering_connection_id = var.pcx_id
  auto_accept   = true

  tags = {
    Name         = "VPC Peering between ${var.vpc_name} and adminVM vpc"
    Environment  = var.vpc_name
    Organization = var.organization_name
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "aws_route" "r" {
  route_table_id              = data.aws_route_table.selected.id
  destination_cidr_block      = var.vpc_cidr_block
  vpc_peering_connection_id   = aws_vpc_peering_connection_accepter.vpcpeering.id
  depends_on                  = [aws_vpc_peering_connection_accepter.vpcpeering]
}

