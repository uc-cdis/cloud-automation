
## The actual data bucket
resource "aws_s3_bucket" "data_bucket" {
  bucket = "${var.vpc_name}-data-bucket"

  tags = {
    Name        = "${var.vpc_name}-data-bucket"
    Environment = var.environment
    Purpose     = "data bucket"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_bucket" {
  bucket = aws_s3_bucket.data_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_logging" "data_bucket" {
  bucket        = aws_s3_bucket.data_bucket.id
  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "log/${var.vpc_name}-data-bucket/"
}

resource "aws_s3_bucket_public_access_block" "data_bucket_privacy" {
  bucket                      = aws_s3_bucket.data_bucket.id
  block_public_acls           = true
  block_public_policy         = true
  ignore_public_acls          = true
  restrict_public_buckets     = true
}

##create an event for SNS
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.data_bucket.id

  topic {
    topic_arn     = module.data-bucket-queue.data-bucket_name
    events        = ["s3:ObjectCreated:Put", "s3:ObjectCreated:Post", "s3:ObjectCreated:Copy", "s3:ObjectCreated:CompleteMultipartUpload" ]
  }
}


## Log bucket, where access to the avobe bucket will be logged
resource "aws_s3_bucket" "log_bucket" {
  bucket = "${var.vpc_name}-data-bucket-logs"

  tags = {
    Name        = var.vpc_name
    Environment = var.environment
    Purpose     = "logs bucket"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.bucket

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
        days = 120
      }
  }
}


resource "aws_s3_bucket_public_access_block" "data_bucket_logs_privacy" {
  bucket                  = aws_s3_bucket.log_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

## We want could trail to put additional logs in this log bucket
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
