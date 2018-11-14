
## The actual data bucket

resource "aws_s3_bucket" "data_bucket" {
  bucket = "${var.vpc_name}-data-bucket"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  logging {
    target_bucket = "${aws_s3_bucket.log_bucket.id}"
    target_prefix = "log/${var.vpc_name}-data-bucket"
  }

  tags {
    Name        = "${var.vpc_name}-data-bucket"
    Environment = "${var.environment}"
    Purpose     = "data bucket"
  }
}



## Log bucket, where access to the avobe bucket will be logged 


resource "aws_s3_bucket" "log_bucket" {
  bucket = "${var.vpc_name}-data-bucket-logs"
  acl    = "bucket-owner-full-control" #log-delivery-write
  acl    = "log-delivery-write"


  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule {
    id      = "log"
    enabled = true

    prefix = "/"

    tags {
      "rule"      = "log"
      "autoclean" = "true"
    }

    expiration {
      days = 120
    }
  }

  tags {
    Name        = "${var.vpc_name}"
    Environment = "${var.environment}"
    Purpose     = "logs bucket"
  }
}




## We want could trail to put additional logs in this log bucket 
resource "aws_s3_bucket_policy" "log_bucket_writer_by_ct" {
  bucket = "${aws_s3_bucket.log_bucket.id}"
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
