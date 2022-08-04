
## Role and Policies for the bucket

resource "aws_iam_role" "data_bucket" {
  name = "${var.vpc_name}-data-bucket-access"
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


## Policies data 

data "aws_iam_policy_document" "data_bucket_reader" {
  statement {
    actions = [
      "s3:Get*",
      "s3:List*"
    ]

    effect    = "Allow"
    resources = [aws_s3_bucket.data_bucket.arn, "${aws_s3_bucket.data_bucket.arn}/*"]
  }
}

data "aws_iam_policy_document" "data_bucket_writer" {
  statement {
    actions = [
      "s3:PutObject"
    ]

    effect    = "Allow"
    resources = [aws_s3_bucket.data_bucket.arn, "${aws_s3_bucket.data_bucket.arn}/*"]
  }
}



## Polcies

resource "aws_iam_policy" "data_bucket_reader" {
  name        = "data_bucket_read_${var.vpc_name}"
  description = "Data Bucket access for ${var.vpc_name}"
  policy      = data.aws_iam_policy_document.data_bucket_reader.json
}

resource "aws_iam_policy" "data_bucket_writer" {
  name        = "data_bucket_write_${var.vpc_name}"
  description = "Data Bucket access for ${var.vpc_name}"
  policy      = data.aws_iam_policy_document.data_bucket_reader.json
}



## Policies attached to roles

resource "aws_iam_role_policy_attachment" "data_bucket_reader" {
  role       = aws_iam_role.data_bucket.name
  policy_arn = aws_iam_policy.data_bucket_reader.arn
}

resource "aws_iam_role_policy_attachment" "data_bucket_writer" {
  role       = aws_iam_role.data_bucket.name
  policy_arn = aws_iam_policy.data_bucket_writer.arn
}





## Role and policies for the log bucket

data "aws_iam_policy_document" "log_bucket_writer" {
  statement {
    actions = [
      "s3:Get*",
      "s3:List*",
    ]

    effect    = "Allow"
    resources = [aws_s3_bucket.log_bucket.arn, "${aws_s3_bucket.log_bucket.arn}/*"]
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

}

resource "aws_iam_policy" "log_bucket_writer" {
  name        = "bucket_writer_${aws_s3_bucket.log_bucket.id}"
  description = "Read or write ${aws_s3_bucket.log_bucket.id}"
  policy      = data.aws_iam_policy_document.log_bucket_writer.json
}
