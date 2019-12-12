
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
  tags {
    Name = "${var.vpc_name}"
  }
}


# Since we need to access the internet through the proxy, let's find it

#data "aws_instances" "squid_proxy" {
#  instance_tags {
    #Name = "${var.vpc_name} HTTP Proxy"
#    Name = "${var.vpc_name}${var.proxy_name}"
#  }
#}


# Also we want to access AWS stuff directly though an existing 
# nat gateway instead than going through the proxy
data "aws_nat_gateway" "the_gateway" {
  vpc_id = "${data.aws_vpc.the_vpc.id}"
}

# Also let's allow comminication through the peering

data "aws_vpc_peering_connection" "pc" {
  vpc_id = "${data.aws_vpc.the_vpc.id}"
  status = "active"
}


# data resources for endpoints 

data "aws_vpc_endpoint_service" "s3" {
  service = "s3"
}

data "aws_vpc_endpoint_service" "logs" {
  service = "logs"
}

# get the route to public kube 
data "aws_route_table" "public_kube" {
  vpc_id      = "${data.aws_vpc.the_vpc.id}"
  tags {
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


data "aws_security_group" "local_traffic" {
  vpc_id = "${data.aws_vpc.the_vpc.id}"
  name   = "local"
}

data "aws_autoscaling_group" "squid_auto" {
  name = "squid-auto-${var.vpc_name}"
}
