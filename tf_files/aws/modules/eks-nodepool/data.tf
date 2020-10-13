
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}


# Let's grab the vpc we already created in the VPC module.

data "aws_vpcs" "vpcs" {
  tags = {
    Name = "${var.vpc_name}"
  }
}

# Assuming that there is only one VPC with the vpc_name
data "aws_vpc" "the_vpc" {
  id = "${element(data.aws_vpcs.vpcs.ids, count.index)}"
}


# Let's get the availability zones for the region we are working on
data "aws_availability_zones" "available" {
  state = "available"
}


# First, let us create a data source to fetch the latest Amazon Machine Image (AMI) that Amazon provides with an
# EKS compatible Kubernetes baked in.

data "aws_ami" "eks_worker" {
  filter {
    name   = "name"
    # values = ["${var.eks_version == "1.10" ? "amazon-eks-node-1.10*" : "amazon-eks-node-1.11*"}"]
    values = ["amazon-eks-node-${var.eks_version}*"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon Account ID
}

#data "aws_eks_cluster" "eks_cluster" {
#  name = "${var.vpc_name}"
#}
