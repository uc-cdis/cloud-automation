resource "aws_s3_bucket" "log_bucket" {
  bucket = local.clean_bucket_name

  tags = {
    Name        = local.clean_bucket_name
    Environment = var.environment
    Purpose     = "logs bucket"
  }
}

#resource "aws_s3_bucket_acl" "log_bucket" {
#  bucket = aws_s3_bucket.log_bucket.id
#  acl    = "log-delivery-write"
#}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    status  = "Enabled"
    id      = "log"

    filter {
      and {
        prefix = "/"

        tags = {
          rule      = "log"
          autoclean = "true"
        }
      }
    }
    expiration {
      # 5 years
      days = 1825
    }
  }
}

resource "aws_s3_bucket_public_access_block" "s3-log_bucket_privacy" {
  bucket                      = aws_s3_bucket.log_bucket.id
  block_public_acls           = true
  block_public_policy         = true
  ignore_public_acls          = true
  restrict_public_buckets     = true
}

#
# Convenience for passing through to kube-aws to
# allow it to configure ELB logging
#
resource "aws_iam_policy" "log_bucket_writer" {
  name        = "bucket_writer_${local.clean_bucket_name}"
  description = "Read or write ${local.clean_bucket_name}"
  policy      = data.aws_iam_policy_document.log_bucket_writer.json
}

#### Added by fauzi@uchicago.edu
# we want cloudtrail to be able to write to this bucket and put additional logs

resource "aws_s3_bucket_policy" "log_bucket_writer_by_ct" {
  bucket = aws_s3_bucket.log_bucket.id
  policy =<<POLICY
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
      "Resource": "${aws_s3_bucket.log_bucket.arn}"
    },
    {
      "Sid": "AWSCloudTrailWrite20150319",
     "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "${aws_s3_bucket.log_bucket.arn}/*",
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
