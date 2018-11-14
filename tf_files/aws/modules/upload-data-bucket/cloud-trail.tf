

resource "aws_cloudtrail" "logger_trail" {
  name                          = "${var.vpc_name}-data-bucket-trail"
  s3_bucket_name                = "${aws_s3_bucket.log_bucket.id}"
  s3_key_prefix                 = "trail-logs"
  include_global_service_events = false
  cloud_watch_logs_role_arn     = "${aws_iam_role.cloudtrail_to_clouodwatch_writer.arn}"
  #cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.main_log_group.arn}"
  #cloud_watch_logs_group_arn    = "${var.cloudwatchlogs_group_arn}"
  #cloud_watch_logs_group_arn    = "${data.aws_cloudwatch_log_group.logs_destination.arn}"
  cloud_watch_logs_group_arn    = "${var.cloudwatchlogs_group}"
  #cloud_watch_logs_group_arn    = "fauziv1"

  event_selector {
    read_write_type = "All"
    include_management_events = false

    data_resource {
      type   = "AWS::S3::Object"
      # Make sure to append a trailing '/' to your ARN if you want
      # to monitor all objects in a bucket.
      values = ["${aws_s3_bucket.data_bucket.arn}/"]
    }
  }
  tags {
    Name        = "${var.vpc_name}_data-bucket"
    Environment = "${var.environment}"
    Purpose     = "trail_for_${var.vpc_name}_data_bucket"
  }
}

