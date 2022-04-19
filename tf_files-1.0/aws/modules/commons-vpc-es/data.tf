# Data to query 


data "aws_availability_zones" "available" {
  state = "available"
}


data "aws_vpcs" "vpcs" {
  tags = {
    Name = "${var.vpc_name}"
  }
}


# Assuming that there is only one VPC with the vpc_name
data "aws_vpc" "the_vpc" {
  id = "${element(data.aws_vpcs.vpcs.ids, count.index)}"
}


data "aws_iam_user" "es_user" {
  user_name = "${var.vpc_name}_es_user"
}

data "aws_cloudwatch_log_group" "logs_group" {
  name = "${var.vpc_name}"
}


data "aws_subnet_ids" "private" {
  vpc_id = "${data.aws_vpc.the_vpc.id}"
  tags = {
    Name = "private_db_alt"
  }
}
