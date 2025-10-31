
# Assuming that there is only one VPC with the vpc_name
data "aws_vpc" "the_vpc" {
  id = "${element(data.aws_vpcs.vpcs.ids, count.index)}"
}

# Let's grab the vpc we already created in the VPC module.
data "aws_vpcs" "vpcs" {
  tags = {
    Name = "${var.vpc_name}"
  }
}

# get the route to public kube
#data "aws_route_table" "public_kube" {
#  vpc_id      = "${data.aws_vpc.the_vpc.id}"
#  tags = {
#    Name = "main"
#  }
#}

data "aws_subnet" "public_kube" {
  vpc_id      = "${data.aws_vpc.the_vpc.id}"
  tags = {
    Name = "eks_public_2"
  }
}


# let's create a data source to fetch the latest Amazon Machine Image (AMI) that Amazon provides with
# EKS compatible Kubernetes baked in.

#data "aws_ami" "eks_worker" {
#  filter {
#    name   = "name"
#    values = ["amazon-eks-node-${var.eks_version}*"]
#  }
#
#  most_recent = true
#  owners      = ["602401143452"] # Amazon Account ID
#}

