terraform {
  backend "s3" {
    encrypt = "true"
  }

  required_providers {
    aws = "~> 2.41"
  }
}

module "cdis_s3_logs" {
  source          = "../s3-logs"
  log_bucket_name = "s3logs-${local.clean_bucket_name}"
  environment     = "${var.environment}"
}

resource "aws_s3_bucket" "mybucket" {
  bucket = "${local.clean_bucket_name}"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule {
    enabled = true
    abort_incomplete_multipart_upload_days = 7
  }

  logging {
    target_bucket = "${module.cdis_s3_logs.log_bucket_name}"
    target_prefix = "log/${local.clean_bucket_name}/"
  }

  tags = {
    Name        = "${local.clean_bucket_name}"
    Environment = "${var.environment}"
    Purpose     = "data bucket"
  }
}

resource "aws_iam_role" "mybucket_reader" {
  name = "bucket_reader_${local.clean_bucket_name}"
  path = "/"

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

data "aws_iam_policy_document" "mybucket_reader" {
  statement {
    actions = [
      "s3:Get*",
      "s3:List*",
    ]

    effect    = "Allow"
    resources = ["${aws_s3_bucket.mybucket.arn}", "${aws_s3_bucket.mybucket.arn}/*"]
  }
}

resource "aws_iam_policy" "mybucket_reader" {
  # This name is used in the `gen3 s3 info` function
  name        = "bucket_reader_${local.clean_bucket_name}"
  description = "Read ${local.clean_bucket_name}"
  policy      = "${data.aws_iam_policy_document.mybucket_reader.json}"
}

resource "aws_iam_role_policy_attachment" "mybucket_reader" {
  role       = "${aws_iam_role.mybucket_reader.name}"
  policy_arn = "${aws_iam_policy.mybucket_reader.arn}"
}

#resource "aws_iam_role_policy" "mybucket_reader" {
#  name   = "bucket_reader_${local.clean_bucket_name}"
#  policy = "${data.aws_iam_policy_document.mybucket_reader.json}"
#  role   = "${aws_iam_role.mybucket_reader.id}"
#}

resource "aws_iam_instance_profile" "mybucket_reader" {
  name = "bucket_reader_${local.clean_bucket_name}"
  role = "${aws_iam_role.mybucket_reader.id}"
}

#----------------------

resource "aws_iam_role" "mybucket_writer" {
  name = "bucket_writer_${local.clean_bucket_name}"
  path = "/"

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

data "aws_iam_policy_document" "mybucket_writer" {
  statement {
    actions = [
      "s3:Get*",
      "s3:List*",
    ]

    effect    = "Allow"
    resources = ["${aws_s3_bucket.mybucket.arn}", "${aws_s3_bucket.mybucket.arn}/*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
    ]

    resources = ["${aws_s3_bucket.mybucket.arn}/*"]
  }
}

resource "aws_iam_policy" "mybucket_writer" {
  # This name is used in the `gen3 s3 info` function
  name        = "bucket_writer_${local.clean_bucket_name}"
  description = "Read or write ${local.clean_bucket_name}"
  policy      = "${data.aws_iam_policy_document.mybucket_writer.json}"
}

resource "aws_iam_role_policy_attachment" "mybucket_writer" {
  role       = "${aws_iam_role.mybucket_writer.name}"
  policy_arn = "${aws_iam_policy.mybucket_writer.arn}"
}

#resource "aws_iam_role_policy" "mybucket_writer" {
#  name   = "bucket_writer_${local.clean_bucket_name}"
#  policy = "${data.aws_iam_policy_document.mybucket_writer.json}"
#  role   = "${aws_iam_role.mybucket_writer.id}"
#}

resource "aws_iam_instance_profile" "mybucket_writer" {
  name = "bucket_writer_${local.clean_bucket_name}"
  role = "${aws_iam_role.mybucket_writer.id}"
}



############################## Added by Fauzi fauzi@uchicago.edu

# let's send the logs to cloudwatch as well

data "aws_cloudwatch_log_group" "logs_destination" {
  name = "${var.environment}"
}

# create the policy and role for the role that will be attached to 
# the trail so it can write cloudwatch

resource "aws_iam_role" "cloudtrail_writer" {
  count = "${var.cloud_trail_count}"
  name = "cwl_writer_${local.clean_bucket_name}"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "cloudtrail.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

data "aws_iam_policy_document" "trail_policy" {
  statement {
    effect    = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["${data.aws_cloudwatch_log_group.logs_destination.arn}"]
  }

}

resource "aws_iam_policy" "trail_writer" {
  count       = "${var.cloud_trail_count}"
  name        = "trail_write_to_cw_${data.aws_cloudwatch_log_group.logs_destination.name}"
  description = "Read or write     ${data.aws_cloudwatch_log_group.logs_destination.name}"
  policy      = "${data.aws_iam_policy_document.trail_policy.json}"
}

resource "aws_iam_role_policy_attachment" "trail_writer_role" {
  count      = "${var.cloud_trail_count}"
  role       = "${aws_iam_role.cloudtrail_writer.*.name[count.index]}"
  policy_arn = "${aws_iam_policy.trail_writer.*.arn[count.index]}"
}


# first we need to create a trail in cloudtrail

resource "aws_cloudtrail" "logger_trail" {
  count                         = "${var.cloud_trail_count}"
  name                          = "${local.clean_bucket_name}-trail"
  s3_bucket_name                = "${module.cdis_s3_logs.log_bucket_name}"
  s3_key_prefix                 = "trailLogs"
  include_global_service_events = false
  cloud_watch_logs_role_arn     = "${aws_iam_role.cloudtrail_writer.*.arn[count.index]}"
  cloud_watch_logs_group_arn    = "${data.aws_cloudwatch_log_group.logs_destination.arn}"

  event_selector {
    read_write_type = "All"
    include_management_events = false

    data_resource {
      type   = "AWS::S3::Object"
      # Make sure to append a trailing '/' to your ARN if you want
      # to monitor all objects in a bucket.
      values = ["${aws_s3_bucket.mybucket.arn}/"]
    }
  }
  tags = {
    Name        = "${local.clean_bucket_name}"
    Environment = "${var.environment}"
    Purpose     = "trail_for_${local.clean_bucket_name}_data_bucket"
  }
}


############################### END added by Fauzi 
