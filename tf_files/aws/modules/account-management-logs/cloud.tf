# We need a bucket for cloud-trail to send logs

resource "aws_s3_bucket" "management-logs_bucket" {
  bucket = "${var.account_name}_management-logs"
  acl    = "private"

  tags {
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

    transition {
      days          = 30
      storage_class = "STANDARD_IA" # or "ONEZONE_IA"
    }

    transition {
      days          = 60
      storage_class = "GLACIER"
    }

    expiration {
      days = 1827
    }
  }

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSCloudTrailAclCheck",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::${var.account_name}_management-logs"
        },
        {
            "Sid": "AWSCloudTrailWrite",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::${var.account_name}_management-logs/*",
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



# We also need a CloudWatchLogGroup so we can hook it up with the CSOC account through a subscription Filter

resource "aws_cloudwatch_log_group" "management-logs_group" {
  name = "${var.account_name}_management-logs"
  tags {
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
      "Action": "sts:AssumeRole",
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "cloudtrail_to_cloudwatch_policy_document" {
  statement {
    actions = [
      "logs:CreateLogsStream",
      "logs:PutLogEvents",
    ]
    effect = "Allow"
    resources = [
      "${aws_cloudwatch_log_group.management-log_group.arn}:*"
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

  is_multi_region_trail = true
  cloud_watch_logs_role_arn = "${aws_iam_role.cloudtrail_role}"
  cloud_watch_logs_group_arn= "${aws_cloudwatch_log_group.management-logs_group.arn}"
  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  s3_bucket_name = "${aws_se_bucket.management-logs_bucket.id}"
  s3_key_prefix = "management-logs"

  tags {
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

