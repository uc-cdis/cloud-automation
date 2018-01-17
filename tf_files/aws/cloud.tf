terraform {
    backend "s3" {
        encrypt = "true"
    }
}

provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region = "${var.aws_region}"
}

module "cdis_vpc" {
  ami_account_id = "${var.ami_account_id}"
  source = "../modules/cdis-aws-vpc"
  vpc_octet = "${var.vpc_octet}"
  vpc_name = "${var.vpc_name}"
}


data "aws_vpc_endpoint_service" "s3" {
    service = "s3"
}

resource "aws_vpc_endpoint" "k8s-s3" {
    vpc_id = "${module.cdis_vpc.vpc_id}"
    #service_name = "com.amazonaws.us-east-1.s3"
    service_name = "${data.aws_vpc_endpoint_service.s3.service_name}"
    route_table_ids = ["${aws_route_table.private_kube.id}"]
}

resource "aws_route_table" "private_kube" {
    vpc_id = "${module.cdis_vpc.vpc_id}"
    route {
        cidr_block = "0.0.0.0/0"
        instance_id = "${module.cdis_vpc.proxy_id}"
    }
    tags {
        Name = "private_kube"
        Environment = "${var.vpc_name}"
        Organization = "Basic Service"
    }
}

resource "aws_route_table_association" "private_kube" {
    subnet_id = "${aws_subnet.private_kube.id}"
    route_table_id = "${aws_route_table.private_kube.id}"
}


resource "aws_subnet" "private_kube" {
    vpc_id = "${module.cdis_vpc.vpc_id}"
    cidr_block = "172.${var.vpc_octet}.36.0/22"
    availability_zone = "${data.aws_availability_zones.available.names[0]}"
    map_public_ip_on_launch = false
    tags = "${map("Name", "private_kube", "Organization", "Basic Service", "Environment", var.vpc_name, "kubernetes.io/cluster/${var.vpc_name}", "owned")}"
}


resource "aws_subnet" "private_db_alt" {
    vpc_id = "${module.cdis_vpc.vpc_id}"
    cidr_block = "172.${var.vpc_octet}.40.0/22"
    availability_zone = "${data.aws_availability_zones.available.names[1]}"
    map_public_ip_on_launch = false
    tags {
        Name = "private_db_alt"
        Environment = "${var.vpc_name}"
        Organization = "Basic Service"
    }
}


resource "aws_db_subnet_group" "private_group" {
    name = "${var.vpc_name}_private_group"
    subnet_ids = ["${aws_subnet.private_kube.id}", "${aws_subnet.private_db_alt.id}"]

    tags {
        Name = "Private subnet group"
        Environment = "${var.vpc_name}"
        Organization = "Basic Service"
    }
    description = "Private subnet group"
}
