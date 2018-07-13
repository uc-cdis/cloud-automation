

data "aws_availability_zones" "available" {
  state = "available"
}


resource "random_shuffle" "az" {
  input = ["${data.aws_availability_zones.available.names}"] #["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d", "us-east-1e", "us-east-1f"]
  result_count = 1
}

output "stuff" {
  value = "${random_shuffle.az.result}"
}

resource "aws_security_group" "private_es" {
  name        = "private_es"
  description = "security group that allow es port out"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["172.${var.vpc_octet2}.${var.vpc_octet3}.0/20"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["172.${var.vpc_octet2}.${var.vpc_octet3}.0/20"]
  }

  tags {
    Environment  = "${var.vpc_name}"
    Organization = "Basic Service"
  }
}


resource "aws_subnet" "private_sn_es" {
  vpc_id                  = "${var.vpc_id}"
  cidr_block              = "172.${var.vpc_octet2}.${var.vpc_octet3 + 6}.0/24"
  availability_zone       = "us-east-1f" #${random_shuffle.az.result}
  map_public_ip_on_launch = false

  tags {
    Name         = "private_es"
    Environment  = "${var.vpc_name}"
    Organization = "Basic Service"
  }
}


resource "aws_elasticsearch_domain" "gen3_metadata" {
  domain_name           = "${var.vpc_name}-gen3-metadata"
  elasticsearch_version = "6.2"
  encrypt_at_rest {
    enabled = "true"
  }
  vpc_options {
    security_group_ids = ["${aws_security_group.private_es.id}"]
    subnet_ids = ["${aws_subnet.private_sn_es.id}"]
  }
  cluster_config {
    instance_type = "m4.large.elasticsearch"
  }
  ebs_options {
    ebs_enabled = "true"
    volume_size = 20
  }

  advanced_options {
    "rest.action.multi.allow_explicit_index" = "true"
  }


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
}

data "aws_iam_user" "es_user" {
  user_name = "${var.vpc_name}_es_user"
} 
