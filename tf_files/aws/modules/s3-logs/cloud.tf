resource "aws_s3_bucket" "log_bucket" {
  bucket = "${local.clean_bucket_name}"
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
    Name        = "${local.clean_bucket_name}"
    Environment = "${var.environment}"
    Purpose     = "logs bucket"
  }
}

#### Added by fauzi@uchicago.edu

data "aws_caller_identity" "current" {}

####


data "aws_iam_policy_document" "log_bucket_writer" {
  statement {
    actions = [
      "s3:Get*",
      "s3:List*",
    ]

    effect    = "Allow"
    resources = ["${aws_s3_bucket.log_bucket.arn}", "${aws_s3_bucket.log_bucket.arn}/*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
    ]

    resources = ["${aws_s3_bucket.log_bucket.arn}/*"]
  }

#### Added by fauzi@uchicago.edu
# we want cloudtrail to be able to write to this bucket and put additional logs

  statement {
    effect = "Allow"

    actions = [
      "s3:GetBucketAcl",
    ]

    resources = ["${aws_s3_bucket.log_bucket.arn}"]

    principals {
      type = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:PutObject",
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"

      values = [
        "bucket-owner-full-control",
      ]
    }

    resources = ["${aws_s3_bucket.log_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

  }
   
####

}

#
# Convenience for passing through to kube-aws to
# allow it to configure ELB logging
#
resource "aws_iam_policy" "log_bucket_writer" {
  name        = "bucket_writer_${local.clean_bucket_name}"
  description = "Read or write ${local.clean_bucket_name}"
  policy      = "${data.aws_iam_policy_document.log_bucket_writer.json}"
}
