provider "aws" {
    region = "us-east-1"
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
}

resource "aws_vpc" "test" {
    cidr_block = "172.17.0.0/16"
    enable_dns_hostnames = true
    tags {
        Name = "test"
    }
}

