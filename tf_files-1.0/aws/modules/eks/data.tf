
#Basics

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}


# Assuming that there is only one VPC with the vpc_name
data "aws_vpc" "the_vpc" {
  id = "${element(data.aws_vpcs.vpcs.ids, count.index)}"
}

# Let's get the availability zones for the region we are working on
data "aws_availability_zones" "available" {
  state = "available"
}


# Let's grab the vpc we already created in the VPC module.
data "aws_vpcs" "vpcs" {
  tags = {
    Name = "${var.vpc_name}"
  }
}


# Since we need to access the internet through the proxy, let's find it


# Also we want to access AWS stuff directly though an existing 
# nat gateway instead than going through the proxy
data "aws_nat_gateway" "the_gateway" {
  vpc_id = "${data.aws_vpc.the_vpc.id}"

  tags = {
    Name = "${var.vpc_name}-ngw"
  }

  state = "available"
}

# Also let's allow comminication through the peering

data "aws_vpc_peering_connection" "pc" {
  vpc_id = "${data.aws_vpc.the_vpc.id}"
  status = "active"
}


# data resources for endpoints 

data "aws_vpc_endpoint_service" "logs" {
  service = "logs"
}

data "aws_vpc_endpoint_service" "ec2" {
  service = "ec2"
}

data "aws_vpc_endpoint_service" "autoscaling" {
  service = "autoscaling"
}

data "aws_vpc_endpoint_service" "ecr_dkr" {
  service = "ecr.dkr"
}

data "aws_vpc_endpoint_service" "ecr_api" {
  service = "ecr.api"
}

data "aws_vpc_endpoint_service" "ebs" {
  service = "ebs"
}

data "aws_vpc_endpoint_service" "sts" {
  service = "sts"
}


# get the route to public kube 
data "aws_route_table" "public_kube" {
  vpc_id      = "${data.aws_vpc.the_vpc.id}"
  tags = {
    Name = "main"
  }
}


# let's create a data source to fetch the latest Amazon Machine Image (AMI) that Amazon provides with
# EKS compatible Kubernetes baked in.

data "aws_ami" "eks_worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${var.eks_version}*"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon Account ID
}

# grab the local traffic sec group
data "aws_security_group" "local_traffic" {
  vpc_id = "${data.aws_vpc.the_vpc.id}"
  name   = "local"
}

# we are going to use the same AZs used for the squid autoscaling group

data "aws_autoscaling_group" "squid_auto" {
  count         = "${var.ha_squid ? 1 : 0}"
  name = "squid-auto-${var.vpc_name}"
}

data "aws_instances" "squid_proxy" {
  count         = "${var.ha_squid ? var.dual_proxy ? 1 : 0 : 1}"
  instance_tags = {
    Name = "${var.vpc_name}${var.proxy_name}"
  }
}


# get the private kube table id
data "aws_route_table" "private_kube_route_table" {
  vpc_id      = "${data.aws_vpc.the_vpc.id}"
  tags = {
    Name = "private_kube"
  }
}

#get the internal zone id
data "aws_route53_zone" "vpczone" {
  name        = "internal.io."
  vpc_id      = "${data.aws_vpc.the_vpc.id}"
}

# let terraform compress our code and serve to lambda
data "archive_file" "lambda_function" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "lambda_function_payload.zip"
}

# policy for the lambda function 1
data "aws_iam_policy_document" "with_resources" {
  statement {
    actions = [
      "ec2:CreateRoute",
      "ec2:DeleteRoute",
      "ec2:ReplaceRoute",
      "route53:GetHostedZone",
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:route-table/${aws_route_table.eks_private.id}",
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:route-table/${data.aws_route_table.private_kube_route_table.id}",
      "arn:aws:route53:::hostedzone/${data.aws_route53_zone.vpczone.zone_id}"
    ]
  }
}

# policy for the lambda function 2
data "aws_iam_policy_document" "without_resources" {
  statement {
    actions = [
      "autoscaling:DescribeAutoScalingInstances",
      "route53:CreateHostedZone",
      "ec2:DescribeInstances",
      "route53:ListHostedZones",
      "ec2:DeleteNetworkInterface",
      "ec2:DisassociateRouteTable",
      "ec2:DescribeSecurityGroups",
      "ec2:AssociateRouteTable",
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "autoscaling:DescribeAutoScalingGroups",
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeRouteTables",
      "ec2:DescribeInstanceAttribute",
      "ec2:ModifyInstanceAttribute"
    ]
    effect = "Allow"
    resources = ["*"]
  }
}

# Policy for access to CSOC sns
data "aws_iam_policy_document" "planx-csoc-alerts-topic_access" {
  count = "${var.sns_topic_arn != "" ? 1 : 0 }"
  statement {
    actions   = [ "sns:Publish" ]
    effect    = "Allow"
    resources = [ "${var.sns_topic_arn}" ]
  }
}
