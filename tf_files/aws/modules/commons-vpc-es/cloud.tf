
resource "aws_iam_service_linked_role" "es" {
  aws_service_name = "es.amazonaws.com"
}

#resource "random_shuffle" "az" {
#  input = ["${data.aws_availability_zones.available.names}"]
#  result_count = 1
#  count = 1
#}


resource "aws_security_group" "private_es" {
  name        = "private_es"
  description = "security group that allow es port out"
  vpc_id      = "${element(data.aws_vpcs.vpcs.ids, count.index)}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${data.aws_vpc.the_vpc.cidr_block}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${data.aws_vpc.the_vpc.cidr_block}"]
  }

  tags {
    Environment  = "${var.vpc_name}"
    Organization = "Basic Service"
  }
}


#resource "aws_subnet" "private_sn_es" {
#  vpc_id                  = "${element(data.aws_vpcs.vpcs.ids, count.index)}"
#  cidr_block              = "${cidrhost(data.aws_vpc.the_vpc.cidr_block, 256 * 6 )}/24"
#  availability_zone       = "${element(random_shuffle.az.result, count.index)}"
#  map_public_ip_on_launch = false

#  tags {
#    Name         = "private_es"
#    Environment  = "${var.vpc_name}"
#    Organization = "Basic Service"
#  }
#}


resource "aws_elasticsearch_domain" "gen3_metadata" {
  domain_name           = "${var.vpc_name}-gen3-metadata"
  elasticsearch_version = "6.3"
  encrypt_at_rest {
    enabled = "true"
  }
  vpc_options {
    security_group_ids = ["${aws_security_group.private_es.id}"]
    subnet_ids = ["${data.aws_subnet_ids.private.ids}"]
  }
  cluster_config {
    instance_type = "m4.large.elasticsearch"
    instance_count = 3
  }
  ebs_options {
    ebs_enabled = "true"
    volume_size = 20
  }

  log_publishing_options {
    log_type = "ES_APPLICATION_LOGS"
    cloudwatch_log_group_arn = "${data.aws_cloudwatch_log_group.logs_group.arn}"
    enabled = "true"
  }

  advanced_options {
    "rest.action.multi.allow_explicit_index" = "true"
  }
  depends_on = ["aws_iam_service_linked_role.es"]

  snapshot_options {
    automated_snapshot_start_hour = 23
  }

  tags {
    Name         = "gen3_metadata"
    Environment  = "${var.vpc_name}"
    Organization = "Basic Service"

  }
   access_policies = <<CONFIG
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "es:*",
            "Principal": {
              "AWS": [
                "${data.aws_iam_user.es_user.arn}"
              ]
            },
            "Effect": "Allow",
            "Resource": "*"
        }
    ]
}
CONFIG

  lifecycle {
    ignore_changes = ["elasticsearch_version"]
  }
}
