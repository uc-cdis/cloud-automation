locals{
  cidrs = var.secondary_cidr_block != "" ? [var.vpc_cidr_block, var.peering_cidr, var.secondary_cidr_block] : [var.vpc_cidr_block, var.peering_cidr]
  cidrs_no_peering = var.secondary_cidr_block != "" ? [var.vpc_cidr_block, var.secondary_cidr_block] : [var.vpc_cidr_block]
}

resource "aws_security_group" "local" {
  name        = "local"
  description = "security group that only allow internal tcp traffics"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = local.cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = local.cidrs_no_peering
  }

  tags = {
    Environment  = var.vpc_name
    Organization = var.organization_name
    Name         = "${var.vpc_name}-local-sec-group"
  }
}

resource "aws_security_group" "out" {
  name        = "out"
  description = "security group that allow outbound traffics"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment  = var.vpc_name
    Organization = var.organization_name
    Name         = "${var.vpc_name}-outbound-traffic"
  }
}

resource "aws_security_group" "proxy" {
  count       = "${var.deploy_single_proxy ? 1 : 0 }"
  name        = "squid-proxy"
  description = "allow inbound tcp at 3128"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 3128
    protocol    = "TCP"
    cidr_blocks = local.cidrs
  }

  tags = {
    Environment  = var.vpc_name
    Organization = "Basic Service"
  }
}
