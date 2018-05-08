module "cdis_s3_logs" {
  source          = "../s3-logs"
  log_bucket_name = "s3logs-${local.clean_bucket_name}"
  environment     = "${var.environment}"
}

resource "aws_s3_bucket" "mybucket" {
  bucket = "${local.clean_bucket_name}"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  logging {
    target_bucket = "${module.cdis_s3_logs.log_bucket_name}"
    target_prefix = "log/${local.clean_bucket_name}"
  }

  tags {
    Name        = "${local.clean_bucket_name}"
    Environment = "${var.environment}"
    Purpose     = "data bucket"
  }
}

resource "aws_iam_role" "mybucket_reader" {
  name = "bucket_reader_${local.clean_bucket_name}"
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

resource "aws_iam_policy" "mybucket_reader" {
  name        = "bucket_reader_${local.clean_bucket_name}"
  description = "Read ${local.clean_bucket_name}"
  policy      = "${data.aws_iam_policy_document.mybucket_reader.json}"
}

resource "aws_iam_role_policy_attachment" "mybucket_reader" {
  role       = "${aws_iam_role.mybucket_reader.name}"
  policy_arn = "${aws_iam_policy.mybucket_reader.arn}"
}

#resource "aws_iam_role_policy" "mybucket_reader" {
#  name   = "bucket_reader_${local.clean_bucket_name}"
#  policy = "${data.aws_iam_policy_document.mybucket_reader.json}"
#  role   = "${aws_iam_role.mybucket_reader.id}"
#}

resource "aws_iam_instance_profile" "mybucket_reader" {
  name = "bucket_reader_${local.clean_bucket_name}"
  role = "${aws_iam_role.mybucket_reader.id}"
}

#----------------------

resource "aws_iam_role" "mybucket_writer" {
  name = "bucket_writer_${local.clean_bucket_name}"
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

  statement {
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
    ]

    resources = ["${aws_s3_bucket.mybucket.arn}/*"]
  }
}

resource "aws_iam_policy" "mybucket_writer" {
  name        = "bucket_writer_${local.clean_bucket_name}"
  description = "Read or write ${local.clean_bucket_name}"
  policy      = "${data.aws_iam_policy_document.mybucket_writer.json}"
}

resource "aws_iam_role_policy_attachment" "mybucket_writer" {
  role       = "${aws_iam_role.mybucket_writer.name}"
  policy_arn = "${aws_iam_policy.mybucket_writer.arn}"
}

#resource "aws_iam_role_policy" "mybucket_writer" {
#  name   = "bucket_writer_${local.clean_bucket_name}"
#  policy = "${data.aws_iam_policy_document.mybucket_writer.json}"
#  role   = "${aws_iam_role.mybucket_writer.id}"
#}

resource "aws_iam_instance_profile" "mybucket_writer" {
  name = "bucket_writer_${local.clean_bucket_name}"
  role = "${aws_iam_role.mybucket_writer.id}"
}
