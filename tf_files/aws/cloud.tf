# Inject credentials via the AWS_PROFILE environment variable and shared credentials file 
# and/or EC2 metadata service
terraform {
  backend "s3" {
    encrypt = "true"
  }
}

# Inject credentials via the AWS_PROFILE environment variable and shared credentials file and/or EC2 metadata service
#
provider "aws" {}

module "cdis_vpc" {
  ami_account_id  = "${var.ami_account_id}"
  source          = "../modules/cdis-aws-vpc"
  vpc_octet2       = "${var.vpc_octet2}"
  vpc_octet3       = "${var.vpc_octet3}"
  vpc_name        = "${var.vpc_name}"
  ssh_key_name    = "${aws_key_pair.automation_dev.key_name}"
  csoc_cidr       = "${var.csoc_cidr}"
  csoc_account_id = "${var.csoc_account_id}"
}

# logs bucket for elb logs
module "elb_logs" {
  source          = "../modules/cdis-s3-logs"
  log_bucket_name = "logs-${var.vpc_name}-gen3"
  environment     = "${var.vpc_name}"
}

data "aws_vpc_endpoint_service" "s3" {
  service = "s3"
}

resource "aws_vpc_endpoint" "k8s-s3" {
  vpc_id = "${module.cdis_vpc.vpc_id}"

  #service_name = "com.amazonaws.us-east-1.s3"
  service_name    = "${data.aws_vpc_endpoint_service.s3.service_name}"
  route_table_ids = ["${aws_route_table.private_kube.id}"]
}

resource "aws_route_table" "private_kube" {
  vpc_id = "${module.cdis_vpc.vpc_id}"

  route {
    cidr_block  = "0.0.0.0/0"
    instance_id = "${module.cdis_vpc.proxy_id}"
  }

  route {
    # cloudwatch logs route
    cidr_block     = "54.224.0.0/12"
    nat_gateway_id = "${module.cdis_vpc.nat_gw_id}"
  }

  route {
    #from the commons vpc to the csoc vpc via the peering connection
    cidr_block                = "${var.csoc_cidr}"
    vpc_peering_connection_id = "${module.cdis_vpc.vpc_peering_id}"
  }

  tags {
    Name         = "private_kube"
    Environment  = "${var.vpc_name}"
    Organization = "Basic Service"
  }
}

resource "aws_default_route_table" "default" {
  vpc_id = "${module.cdis_vpc.vpc_id}"
  default_route_table_id = "${aws_vpc.${var.vpc_name}.default_route_table_id}"
  route {
    #from the commons vpc to the csoc vpc via the peering connection
    cidr_block                = "${var.csoc_cidr}"
    vpc_peering_connection_id = "${module.cdis_vpc.vpc_peering_id}"
  }

  tags {
    Name = "default table"
  }
}

resource "aws_route_table_association" "private_kube" {
  subnet_id      = "${aws_subnet.private_kube.id}"
  route_table_id = "${aws_route_table.private_kube.id}"
}

resource "aws_main_route_table_association" "default" {
  subnet_id      = "${aws_subnet.private_db_alt.id}"
  route_table_id = "${aws_default_route_table.default.id}"

}

resource "aws_subnet" "private_kube" {
  vpc_id                  = "${module.cdis_vpc.vpc_id}"
  cidr_block              = "172.${var.vpc_octet2}.${var.vpc_octet3 + 2}.0/24"
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"
  map_public_ip_on_launch = false
  tags                    = "${map("Name", "private_kube", "Organization", "Basic Service", "Environment", var.vpc_name, "kubernetes.io/cluster/${var.vpc_name}", "owned")}"
}

resource "aws_subnet" "private_db_alt" {
  vpc_id                  = "${module.cdis_vpc.vpc_id}"
  cidr_block              = "172.${var.vpc_octet2}.${var.vpc_octet3 + 3}.0/24"
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"
  map_public_ip_on_launch = false

  tags {
    Name         = "private_db_alt"
    Environment  = "${var.vpc_name}"
    Organization = "Basic Service"
  }
}

resource "aws_db_subnet_group" "private_group" {
  name       = "${var.vpc_name}_private_group"
  subnet_ids = ["${aws_subnet.private_kube.id}", "${aws_subnet.private_db_alt.id}"]

  tags {
    Name         = "Private subnet group"
    Environment  = "${var.vpc_name}"
    Organization = "Basic Service"
  }

  description = "Private subnet group"
}
