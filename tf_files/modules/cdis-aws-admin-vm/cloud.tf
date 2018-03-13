data "aws_ami" "public_cdis_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu16-docker-base-1.0.2-*"]
  }

  owners = ["${var.ami_account_id}"]
}

resource "aws_ami_copy" "cdis_ami" {
  name              = "ub16-cdis-crypt-1.0.2-${var.child_name}"
  description       = "A copy of ubuntu16-docker-base-1.0.2"
  source_ami_id     = "${data.aws_ami.public_cdis_ami.id}"
  source_ami_region = "us-east-1"
  encrypted         = true

  tags {
    Name        = "cdis"
    Environment = "${var.child_name}"
  }

  lifecycle {
    #
    # Do not force update when new ami becomes available.
    # We still need to improve our mechanism for tracking .ssh/authorized_keys
    # User can use 'terraform state taint' to trigger update.
    #
    ignore_changes = ["source_ami_id"]
  }
}

#------- IAM setup ---------------------

#
# Create a role that can assume the 'admin' role of another account.
# We'll wrap our admin VM with an instance profile that
# injects this role into the VM
#
resource "aws_iam_role" "child_role" {
  name = "${var.child_name}_role"
  path = "/"

  # https://www.terraform.io/docs/providers/aws/r/iam_role_policy.html
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

#
# child_role can only STS assume another role (probably the admin role of the child account),
# plus cloudwatch logs ...
#
data "aws_iam_policy_document" "child_policy_document" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:GetLogEvents",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutRetentionPolicy",
    ]

    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    # see https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_permissions-to-switch.html
    actions = ["sts:AssumeRole"]

    effect    = "Allow"
    resources = ["arn:aws:iam::${var.child_account_id}:role/*"]
  }
}

resource "aws_iam_role_policy" "child_policy" {
  name   = "${var.child_name}_child_policy"
  policy = "${data.aws_iam_policy_document.child_policy_document.json}"
  role   = "${aws_iam_role.child_role.id}"
}

resource "aws_iam_instance_profile" "child_role_profile" {
  name = "${var.child_name}_child_role_profile"
  role = "${aws_iam_role.child_role.id}"
}

#------------------------------
#------------ Security Group Setup

resource "aws_security_group" "ssh" {
  name        = "ssh"
  description = "security group that only enables ssh"
  vpc_id      = "${var.csoc_vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Environment  = "${var.child_name}"
    Organization = "Basic Service"
  }
}

resource "aws_security_group" "login-ssh" {
  name        = "login-ssh"
  description = "security group that only enables ssh from login node"
  vpc_id      = "${var.csoc_vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["10.0.0.0/32"]
  }

  tags {
    Environment = "${var.child_name}"
  }
}

resource "aws_security_group" "local" {
  name        = "local"
  description = "security group that only allow internal tcp traffics"
  vpc_id      = "${var.csoc_vpc_id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.128.0.0/20"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    # 54.224.0.0/12 logs.us-east-1.amazonaws.com
    #  cidr_blocks = ["${var.vpc_cidr_octet}", "54.224.0.0/12"]
    cidr_blocks = ["172.24.${var.vpc_cidr_octet}.0/20", "54.224.0.0/12"]
  }

  tags {
    Environment = "${var.child_name}"
  }
}


# Creating the loggroup prior the instance comes up so we can set a retention period 
# and use it for other things if we wanted to
resource "aws_cloudwatch_log_group" "child_log_group" {
    name = "${var.child_name}"
    retention_in_days = "1827"
    tags {
        Environment = "${var.child_name}"
        Organization = "Basic Service"
    }
}

#--------------------------

resource "aws_instance" "login" {
  ami                    = "${aws_ami_copy.cdis_ami.id}"
  subnet_id              = "${var.csoc_subnet_id}"
  instance_type          = "t2.micro"
  monitoring             = true
  key_name               = "${var.ssh_key_name}"
  vpc_security_group_ids = ["${aws_security_group.ssh.id}", "${aws_security_group.local.id}"]
  iam_instance_profile   = "${aws_iam_instance_profile.child_role_profile.name}"

  tags {
    Name        = "${var.child_name}_admin"
    Environment = "${var.child_name}"
  }

  lifecycle {
    ignore_changes = ["ami", "key_name"]
  }

  user_data = <<EOF
#!/bin/bash 

sed -i 's/SERVER/login_node-auth-{hostname}-{instance_id}/g' /var/awslogs/etc/awslogs.conf
sed -i 's/VPC/'${var.child_name}'/g' /var/awslogs/etc/awslogs.conf
cat >> /var/awslogs/etc/awslogs.conf <<EOM
[syslog]
datetime_format = %b %d %H:%M:%S
file = /var/log/syslog
log_stream_name = login_node-syslog-{hostname}-{instance_id}
time_zone = LOCAL
log_group_name = ${var.child_name}
EOM

chmod 755 /etc/init.d/awslogs
systemctl enable awslogs
systemctl restart awslogs
EOF
}

#
#resource "aws_route53_zone" "main" {
#  name    = "internal.io"
#  comment = "internal dns server for ${var.child_name}"
#  vpc_id  = "${var.csoc_vpc_id}"
#
#  tags {
#    Environment  = "${var.child_name}"
#    Organization = "Basic Service"
#  }
#}
#
#resource "aws_route53_record" "squid" {
#  zone_id = "${aws_route53_zone.main.zone_id}"
#  name    = "cloud-proxy"
#  type    = "A"
#  ttl     = "300"
#  records = ["${aws_instance.proxy.private_ip}"]
#}
#



# We need a bucket so we can upload logs from Elastic Search, logs from the child account, and 
# Kinesis stream logs

resource "aws_s3_bucket" "child_account_bucket" {
  bucket = "${var.child_name}"
  acl    = "private"
  tags {
    Environment  = "${var.child_name}"
    Organization = "Basic Service"
  }
}

############################ Start Kinesis Stream and destination #################
## This is all for the stream of logs that'll be send over from the child account 

resource "aws_kinesis_stream" "child_stream" {
    name = "${var.child_name}"
    shard_count = 1
    tags {
        Environment = "${var.child_name}"
        Organization = "Basic Service"
    }
}


resource "aws_iam_role" "cwl_to_kinesis_role" {
  name = "${var.child_name}_cwl_to_kinesis_role"
  path = "/"

  # https://www.terraform.io/docs/providers/aws/r/iam_role_policy.html
  assume_role_policy = <<EOF
{
  "Statement": {
    "Effect": "Allow",
    "Principal": { 
      "Service": "logs.${var.aws_region}.amazonaws.com" 
    },
    "Action": "sts:AssumeRole"
  }
}
EOF
}


# lets allow incoming logs to assume the role that logs can push stuff into kinesis 
#
data "aws_iam_policy_document" "cwltok_policy_document" {
  statement {
    actions = ["kinesis:PutRecord"]
    effect    = "Allow"
    resources = ["arn:aws:kinesis:${var.aws_region}:${var.csoc_account_id}:stream/${aws_kinesis_stream.child_stream.name}"]
  }

  statement {
    actions = ["iam:PassRole"]
    effect    = "Allow"
    resources = ["arn:aws:iam::${var.csoc_account_id}:role/${aws_iam_role.child_cwl_to_kinesis_role.name}"]
  }
}

resource "aws_iam_role_policy" "cwltok_policy" {
  name   = "${var.child_name}_cwltok_policy"
  policy = "${data.aws_iam_policy_document.cwltok_policy_document.json}"
  role   = "${aws_iam_role.cwl_to_kinesis_role.id}"
}

# Let's create the destination for the logs to come and put them into kinesis
resource "aws_cloudwatch_log_destination" "child_logs_destination" {
  name = "${var.child_name}_logs_destination"
  role_arn = "${aws_iam_role.cwl_to_kinesis_role.arn}"
  target_arn = "${aws_kinesis_stream.child_stream.arn}"
}

data "aws_iam_policy_document" "child_logs_destination_policy" {
  statement {
    effect = "Allow"
    principals = {
      type = "AWS"
      identifiers = [
        "${var.child_account_id}",
      ]
    }
    actions = [
      "logs:PutSubscriptionFilter",
    ]
    resources = [
      "${aws_cloudwatch_log_destination.child_logs_destination.arn}" ,
    ]
  }
}

resource "aws_cloudwatch_log_destination_policy" "child_logs_destination_poplicy" {
  destination_name = "${aws_cloudwatch_log_destination.child_logs_destination.name}"
  access_policy = "${data.aws_iam_policy_document.child_logs_destination_policy.json}"
}


############################ End Kinesis Stream and destination #################


############################ Begin Kinesis Firehose #############################

resource "aws_elasticsearch_domain" "test_cluster" {
  domain_name = "firehose-es-test"
}

data "aws_iam_policy_document" "firehose_policy_document" {
  statement {
    actions = [
      "s3:ListBucketMultipartUploads",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:GetObject",
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "kinesis:GetShardIterator",
      "kinesis:DescribeStream",
      "kinesis:GetRecords",
      "lambda:GetFunctionConfiguration",
      "lambda:InvokeFunction",
      "logs:PutLogEvents"
    ]
    effect    = "Allow"
    resources = [
      "arn:aws:logs:us-east-1:433568766270:log-group:/aws/kinesisfirehose/fauziv1:log-stream:*",
      "arn:aws:kinesis:us-east-1:433568766270:stream/%FIREHOSE_STREAM_NAME%",
      "arn:aws:lambda:us-east-1:433568766270:function:%FIREHOSE_DEFAULT_FUNCTION%:%FIREHOSE_DEFAULT_VERSION%",
      "arn:aws:s3:::%FIREHOSE_BUCKET_NAME%",
      "arn:aws:s3:::%FIREHOSE_BUCKET_NAME%/*"
    ]
  }

  statement {
    actions = [ 
      "firehose:PutRecordBatch",
      "firehose:PutRecord",
    ]
    effect    = "Allow"
    resources = ["*"]
  }
}


resource "aws_kinesis_firehose_delivery_stream" "firehose_to_es" {
  name        = "${var.child_name}_firehose"
  destination = "elasticsearch"

  s3_configuration {
    role_arn           = "${aws_iam_role.firehose_role.arn}"
    bucket_arn         = "${aws_s3_bucket.bucket.arn}"
    buffer_size        = 10
    buffer_interval    = 400
    compression_format = "GZIP"
  }

  elasticsearch_configuration {
    domain_arn = "${aws_elasticsearch_domain.test_cluster.arn}"
    role_arn   = "${aws_iam_role.firehose_role.arn}"
    index_name = "test"
    type_name  = "test"
  }
}

############################ End Kinesis Firehose #############################



############################ Begin Lambda function  #############################


data "aws_iam_policy_document" "lamda_policy_document" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    effect    = "Allow"
    resources = ["${aws_cloudwatch_log_group.child_log_group.arn}"]
  }

  statement {
    actions = [ 
      "firehose:PutRecordBatch",
      "firehose:PutRecord",
    ]
    effect    = "Allow"
    resources = ["*"]
  }
}


resource "aws_iam_role" "iam_for_lambda" {
  name = "${var.child_name}_lambda"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_function" "logs_decodeding" {
  filename         = "lambda_function_payload.zip"
  function_name    = "${var.child_name}_lambda"
  role             = "${aws_iam_role.iam_for_lambda.arn}"
  handler          = "exports.test"
  source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  runtime          = "nodejs4.3"

  environment {
    variables = {
      foo = "bar"
    }
  }
}


############################ End Lambda function  ############################





