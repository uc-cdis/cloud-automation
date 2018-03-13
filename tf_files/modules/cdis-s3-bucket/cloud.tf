resource "aws_s3_bucket" "log_bucket" {
  bucket = "s3logs_from_${var.bucket_name}"
  acl    = "log-delivery-write"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags {
    Name        = "s3logs_from_${var.bucket_name}"
    Environment = "${var.environment}"
    Purpose     = "logs bucket"
  }
}

#-------------------------

resource "aws_s3_bucket" "mybucket" {
  bucket = "${var.bucket_name}"
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
    target_prefix = "log/${var.bucket_name}"
  }

  tags {
    Name        = "${var.bucket_name}"
    Environment = "${var.environment}"
    Purpose     = "data bucket"
  }
}

resource "aws_iam_role" "mybucket_reader" {
  name = "bucket_reader_${var.bucket_name}"
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

resource "aws_iam_role_policy" "mybucket_reader" {
  name   = "bucket_reader_${var.bucket_name}"
  policy = "${data.aws_iam_policy_document.mybucket_reader.json}"
  role   = "${aws_iam_role.mybucket_reader.id}"
}

resource "aws_iam_instance_profile" "mybucket_reader" {
  name = "bucket_reader_${var.bucket_name}"
  role = "${aws_iam_role.mybucket_reader.id}"
}

#----------------------

resource "aws_iam_role" "mybucket_writer" {
  name = "bucket_writer_${var.bucket_name}"
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
}

resource "aws_iam_role_policy" "mybucket_writer" {
  name   = "bucket_writer_${var.bucket_name}"
  policy = "${data.aws_iam_policy_document.mybucket_writer.json}"
  role   = "${aws_iam_role.mybucket_writer.id}"
}

resource "aws_iam_instance_profile" "mybucket_writer" {
  name = "bucket_writer_${var.bucket_name}"
  role = "${aws_iam_role.mybucket_writer.id}"
}
