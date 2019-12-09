
resource "aws_vpc_endpoint" "ec2" {
  vpc_id       = "${data.aws_vpc.the_vpc.id}"
  service_name = "com.amazonaws.${data.aws_region.current.name}.ec2"
  vpc_endpoint_type = "Interface"
  security_group_ids  = [
    "${data.aws_security_group.local_traffic.id}"
  ]

  private_dns_enabled = true
  subnet_ids       = ["${aws_subnet.eks_private.*.id}"]
  tags {
    Name         = "to ec2"
    Environment  = "${var.vpc_name}"
    Organization = "${var.organization_name}"
  }
}


resource "aws_vpc_endpoint" "autoscaling" {
  vpc_id       = "${data.aws_vpc.the_vpc.id}"
  service_name = "com.amazonaws.${data.aws_region.current.name}.autoscaling"
  vpc_endpoint_type = "Interface"
  security_group_ids  = [
    "${data.aws_security_group.local_traffic.id}"
  ]

  private_dns_enabled = true
  subnet_ids       = ["${aws_subnet.eks_private.*.id}"]
  tags {
    Name         = "to autoscaling"
    Environment  = "${var.vpc_name}"
    Organization = "${var.organization_name}"
  }
}

resource "aws_vpc_endpoint" "ecr-dkr" {
  vpc_id       = "${data.aws_vpc.the_vpc.id}"
  service_name = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type = "Interface"

  security_group_ids  = [
    "${data.aws_security_group.local_traffic.id}"
  ]
    #"${aws_security_group.eks_nodes_sg.id}"

  private_dns_enabled = true
  subnet_ids       = ["${aws_subnet.eks_private.*.id}"]
  tags {
    Name         = "to ecr"
    Environment  = "${var.vpc_name}"
    Organization = "${var.organization_name}"
  }
}


resource "aws_vpc_endpoint" "ebs" {
  vpc_id       = "${data.aws_vpc.the_vpc.id}"
  service_name = "com.amazonaws.${data.aws_region.current.name}.ebs"
  vpc_endpoint_type = "Interface"
  security_group_ids  = [
    "${data.aws_security_group.local_traffic.id}"
  ]

  private_dns_enabled = true
  subnet_ids       = ["${aws_subnet.eks_private.*.id}"]
  tags {
    Name         = "to autoscaling"
    Environment  = "${var.vpc_name}"
    Organization = "${var.organization_name}"
  }
}
