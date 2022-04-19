
# EC2 endpoint
resource "aws_vpc_endpoint" "ec2" {
  vpc_id       = "${data.aws_vpc.the_vpc.id}"
  #service_name = "com.amazonaws.${data.aws_region.current.name}.ec2"
  service_name    = "${data.aws_vpc_endpoint_service.ec2.service_name}"
  vpc_endpoint_type = "Interface"
  security_group_ids  = [
    "${data.aws_security_group.local_traffic.id}"
  ]

  private_dns_enabled = true
  subnet_ids       = ["${aws_subnet.eks_private.*.id}"]
  tags = {
    Name         = "to ec2"
    Environment  = "${var.vpc_name}"
    Organization = "${var.organization_name}"
  }
}

# Required for sa-linked IAM roles
resource "aws_vpc_endpoint" "sts" {
  vpc_id       = "${data.aws_vpc.the_vpc.id}"
  service_name    = "${data.aws_vpc_endpoint_service.sts.service_name}"
  vpc_endpoint_type = "Interface"
  security_group_ids  = [
    "${data.aws_security_group.local_traffic.id}"
  ]

  private_dns_enabled = true
  subnet_ids       = ["${aws_subnet.eks_private.*.id}"]
  tags = {
    Name         = "to sts"
    Environment  = "${var.vpc_name}"
    Organization = "${var.organization_name}"
  }
}

# Autoscaling endpoint
resource "aws_vpc_endpoint" "autoscaling" {
  vpc_id       = "${data.aws_vpc.the_vpc.id}"
  #service_name = "com.amazonaws.${data.aws_region.current.name}.autoscaling"
  service_name    = "${data.aws_vpc_endpoint_service.autoscaling.service_name}"
  vpc_endpoint_type = "Interface"
  security_group_ids  = [
    "${data.aws_security_group.local_traffic.id}"
  ]

  private_dns_enabled = true
  subnet_ids       = ["${aws_subnet.eks_private.*.id}"]
  tags = {
    Name         = "to autoscaling"
    Environment  = "${var.vpc_name}"
    Organization = "${var.organization_name}"
  }
}

# ECR DKR endpoint 
resource "aws_vpc_endpoint" "ecr-dkr" {
  vpc_id       = "${data.aws_vpc.the_vpc.id}"
  #service_name = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  service_name    = "${data.aws_vpc_endpoint_service.ecr_dkr.service_name}"
  vpc_endpoint_type = "Interface"

  security_group_ids  = [
    "${data.aws_security_group.local_traffic.id}"
  ]

  private_dns_enabled = true
  subnet_ids       = ["${aws_subnet.eks_private.*.id}"]
  tags = {
    Name         = "to ecr dkr"
    Environment  = "${var.vpc_name}"
    Organization = "${var.organization_name}"
  }
}

# ECR API endpoint 
resource "aws_vpc_endpoint" "ecr-api" {
  vpc_id       = "${data.aws_vpc.the_vpc.id}"
  #service_name = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  service_name    = "${data.aws_vpc_endpoint_service.ecr_api.service_name}"
  vpc_endpoint_type = "Interface"

  security_group_ids  = [
    "${data.aws_security_group.local_traffic.id}"
  ]

  private_dns_enabled = true
  subnet_ids       = ["${aws_subnet.eks_private.*.id}"]
  tags = {
    Name         = "to ecr api"
    Environment  = "${var.vpc_name}"
    Organization = "${var.organization_name}"
  }
}

# EBS endpoint
resource "aws_vpc_endpoint" "ebs" {
  vpc_id       = "${data.aws_vpc.the_vpc.id}"
  #service_name = "com.amazonaws.${data.aws_region.current.name}.ebs"
  service_name    = "${data.aws_vpc_endpoint_service.ebs.service_name}"
  vpc_endpoint_type = "Interface"
  security_group_ids  = [
    "${data.aws_security_group.local_traffic.id}"
  ]

  private_dns_enabled = true
  subnet_ids       = ["${aws_subnet.eks_private.*.id}"]
  tags = {
    Name         = "to ebs"
    Environment  = "${var.vpc_name}"
    Organization = "${var.organization_name}"
  }
}


#  S3 endpoint
resource "aws_vpc_endpoint" "k8s-s3" {
  vpc_id          =  "${data.aws_vpc.the_vpc.id}"
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
  route_table_ids = ["${data.aws_route_table.public_kube.id}", "${aws_route_table.eks_private.*.id}"]
  tags = {
    Name         = "to s3"
    Environment  = "${var.vpc_name}"
    Organization = "${var.organization_name}"
  }
  depends_on     = ["aws_route_table.eks_private"]
}

# Cloudwatch logs endpoint
resource "aws_vpc_endpoint" "k8s-logs" {
  vpc_id              = "${data.aws_vpc.the_vpc.id}"
  service_name        = "${data.aws_vpc_endpoint_service.logs.service_name}"
  vpc_endpoint_type   = "Interface"

  security_group_ids  = [
    "${data.aws_security_group.local_traffic.id}"
  ]

  private_dns_enabled = true
  subnet_ids       = ["${aws_subnet.eks_private.*.id}"]
  lifecycle {
    #ignore_changes = ["subnet_ids"]
  }
  tags = {
    Name         = "to cloudwatch logs"
    Environment  = "${var.vpc_name}"
    Organization = "${var.organization_name}"
  }
}
