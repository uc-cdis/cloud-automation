#
# Disable for now
# TODO - combine this with the account-management-logs setup
#

#resource "aws_cloudtrail" "cloudtrail" {
#  name                          = "cloudtrail"
#  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
#  s3_key_prefix                 = "prefix"
#  include_global_service_events = false
#}
#
#resource "aws_s3_bucket" "cloudtrail" {
#  count                         = 0
#  bucket        = "${data.aws_caller_identity.current.account_id}-cloudtrail"
#  force_destroy = true
#
#  policy = <<POLICY
#{
#    "Version": "2012-10-17",
#    "Statement": [
#        {
#            "Sid": "AWSCloudTrailAclCheck",
#            "Effect": "Allow",
#            "Principal": {
#              "Service": "cloudtrail.amazonaws.com"
#            },
#            "Action": "s3:GetBucketAcl",
#            "Resource": "arn:aws:s3:::${data.aws_caller_identity.current.account_id}-cloudtrail"
#        },
#        {
#            "Sid": "AWSCloudTrailWrite",
#            "Effect": "Allow",
#            "Principal": {
#              "Service": "cloudtrail.amazonaws.com"
#            },
#            "Action": "s3:PutObject",
#            "Resource": "arn:aws:s3:::${data.aws_caller_identity.current.account_id}-cloudtrail/prefix/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
#            "Condition": {
#                "StringEquals": {
#                    "s3:x-amz-acl": "bucket-owner-full-control"
#                }
#            }
#        }
#    ]
#}
#POLICY
#}

