
#Basics

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}


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

data "aws_instances" "squid_proxy" {
  instance_tags {
    Name = "${var.vpc_name} HTTP Proxy"
  }
}


# Also we want to access AWS stuff directly though an existing 
# nat gateway instead than going through the proxy
data "aws_nat_gateway" "the_gateway" {
  vpc_id = "${data.aws_vpc.the_vpc.id}"
}

# Also let's allow comminication through the peering

data "aws_vpc_peering_connection" "pc" {
  vpc_id          = "${data.aws_vpc.the_vpc.id}"
}


# Finally lets allow the nodes to access S3 directly 

data "aws_vpc_endpoint_service" "s3" {
  service = "s3"
}



data "aws_route_table" "public_kube" {
  vpc_id      = "${data.aws_vpc.the_vpc.id}"
  tags {
    Name = "main"
  }
}
