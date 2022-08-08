resource "aws_cloudtrail" "logger_trail" {
  name                          = "${var.vpc_name}-data-bucket-trail"
  s3_bucket_name                = var.bucket_id
  s3_key_prefix                 = "trail-logs"
  include_global_service_events = false
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_to_cloudwatch_writer.arn
  cloud_watch_logs_group_arn    = "${var.cloudwatchlogs_group}:*"

  event_selector {
    read_write_type = "All"
    include_management_events = false

    data_resource {
      type   = "AWS::S3::Object"
      # Make sure to append a trailing '/' to your ARN if you want
      # to monitor all objects in a bucket.
      values = ["${var.bucket_arn}/"]
    }
  }

  lifecycle {
    ignore_changes = all
  }
  
  tags = {
    Name        = "${var.vpc_name}_data-bucket"
    Environment = var.environment
    Purpose     = "trail_for_${var.vpc_name}_data_bucket"
  }  
}

## CloudwatchLog access

resource "aws_iam_role" "cloudtrail_to_cloudwatch_writer" {
  name               = "${var.vpc_name}_data-bucket_ct_to_cwl_writer"
  path               = "/"
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

resource "aws_iam_policy" "trail_writer" {
  name        = "trail_write_to_cwl_${var.environment}"
  description = "Put logs in CWL ${var.environment}"
  policy      = data.aws_iam_policy_document.trail_policy.json
}

resource "aws_iam_role_policy_attachment" "trail_writer_role" {
  role       = aws_iam_role.cloudtrail_to_cloudwatch_writer.name
  policy_arn = aws_iam_policy.trail_writer.arn
}