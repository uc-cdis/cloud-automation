# We need a bucket for cloud-trail to send logs

#module "metrics-alerts" {
#  source        = "../account-management-metrics"
#  cwl_group     = "${aws_cloudwatch_log_group.management-logs_group.name}"
#  alarm_actions = "${var.alarm_actions}"
#}



resource "aws_s3_bucket" "management-logs_bucket" {
  bucket = "${var.account_name}-management-logs"
  acl    = "private"

  tags = {
    Environment  = "${var.account_name}"
    Organization = "CTDS"
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule {
    id      = "management-logs"
    enabled = true

    prefix = "management-logs/"

    tags = {
      "rule"      = "log"
      "autoclean" = "true"
    }

    # ONEZONE_IA should be suffice since we have the logs already in CSOC
    transition {
      days          = 30
      storage_class = "ONEZONE_IA" # or "STANDARD_IA" or "INTELLIGENT_TIERING"
    }

    # Reduse some costs after 60 days 
    transition {
      days          = 60
      storage_class = "GLACIER"
    }

    #Logs are being sent over to CSOC, there is no need to keep 5 years worth of logs on both account
    expiration {
      days = 120
    }
  }
}


locals {
  bucket_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSCloudTrailAclCheck20150319",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::${var.account_name}-management-logs"
        },
        {
            "Sid": "AWSCloudTrailWrite20150319",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "*",
            "Resource": "arn:aws:s3:::${var.account_name}-management-logs/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control"
                }
            }
        }
    ]
}
POLICY
}


resource "aws_s3_bucket_policy" "b" {
  bucket = "${aws_s3_bucket.management-logs_bucket.id}"

  policy = "${local.bucket_policy}"
}


# We also need a CloudWatchLogGroup so we can hook it up with the CSOC account through a subscription Filter

resource "aws_cloudwatch_log_group" "management-logs_group" {
  name = "${var.account_name}_management-logs"
  tags = {
    Environment = "ALL"
    Organization = "CTDS"
  }
  retention_in_days = 1827
}

resource "aws_iam_role" "cloudtrail_role" {
  name = "management-logs_cloudtrail_role"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "cloudtrail_to_cloudwatch_policy_document" {
  statement {
    actions = [
      "logs:*",
#      "logs:CreateLogsStream",
#      "logs:PutLogEvents",
    ]
    effect = "Allow"
    resources = [
      "${aws_cloudwatch_log_group.management-logs_group.arn}:*"
    ]
  }
}


resource "aws_iam_role_policy" "cloudtrail_to_cloudwatch_policy" {
  name   = "${var.account_name}_management-logs_policy"
  policy = "${data.aws_iam_policy_document.cloudtrail_to_cloudwatch_policy_document.json}"
  role   = "${aws_iam_role.cloudtrail_role.id}"
}



# Create the trail

resource "aws_cloudtrail" "logs-trail" {

  name                        = "${var.account_name}_management_trail"
  is_multi_region_trail       = true
  cloud_watch_logs_role_arn   = "${aws_iam_role.cloudtrail_role.arn}"
  cloud_watch_logs_group_arn  = "${aws_cloudwatch_log_group.management-logs_group.arn}"
  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  s3_bucket_name = "${aws_s3_bucket.management-logs_bucket.id}"
  s3_key_prefix = "management-logs"

  tags = {
    Environment = "${var.account_name}"
    Organization = "CTDS"
  }
}


# Finally the subscription filter

resource "aws_cloudwatch_log_subscription_filter" "csoc_subscription" {
  name            = "${var.account_name}_subscription"
  destination_arn = "arn:aws:logs:${data.aws_region.current.name}:${var.csoc_account_id}:destination:management-logs_logs_destination"
  log_group_name  = "${aws_cloudwatch_log_group.management-logs_group.name}"
  filter_pattern  = ""
}
