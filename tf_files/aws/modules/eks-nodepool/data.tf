
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}


# Let's grab the vpc we already created in the VPC module.

data "aws_vpcs" "vpcs" {
  tags {
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


# get the subnets 
#data "aws_subnet_ids" "private" {
#  vpc_id = "${data.aws_vpc.the_vpc.id}"
#  tags {
#    Name = "eks_private_*"
#  }
#}


#data "aws_subnet" "eks_private" {
#  count = "${length(data.aws_subnet_ids.private.ids)}"
#  id    = "${data.aws_subnet_ids.private.ids[count.index]}"
#}



# Apparently we cannot iterate over the resource, therefore I am querying them after creation
#data "aws_subnet_ids" "public_kube" {
#  vpc_id = "${data.aws_vpc.the_vpc.id}"
#  tags {
#    Name = "eks_public_*"
#  }
#}

# First, let us create a data source to fetch the latest Amazon Machine Image (AMI) that Amazon provides with an
# EKS compatible Kubernetes baked in.

data "aws_ami" "eks_worker" {
  filter {
    name   = "name"
    #values = ["amazon-eks-node-*"]
    values = ["eks-worker-v*"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon Account ID
}

#data "aws_eks_cluster" "eks_cluster" {
#  name = "${var.vpc_name}"
#}
