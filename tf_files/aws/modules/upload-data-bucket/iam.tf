
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
    resources = ["${aws_s3_bucket.data_bucket.arn}", "${aws_s3_bucket.data_bucket.arn}/*"]
  }
}

data "aws_iam_policy_document" "data_bucket_writer" {
  statement {
    actions = [
      "s3:PutObject"
    ]

    effect    = "Allow"
    resources = ["${aws_s3_bucket.data_bucket.arn}", "${aws_s3_bucket.data_bucket.arn}/*"]
  }
}



## Polcies

resource "aws_iam_policy" "data_bucket_reader" {
  name        = "data_bucket_read_${var.vpc_name}"
  description = "Data Bucket access for ${var.vpc_name}"
  policy      = "${data.aws_iam_policy_document.data_bucket_reader.json}"
}

resource "aws_iam_policy" "data_bucket_writer" {
  name        = "data_bucket_write_${var.vpc_name}"
  description = "Data Bucket access for ${var.vpc_name}"
  policy      = "${data.aws_iam_policy_document.data_bucket_reader.json}"
}



## Policies attached to roles

resource "aws_iam_role_policy_attachment" "data_bucket_reader" {
  role       = "${aws_iam_role.data_bucket.name}"
  policy_arn = "${aws_iam_policy.data_bucket_reader.arn}"
}

resource "aws_iam_role_policy_attachment" "data_bucket_writer" {
  role       = "${aws_iam_role.data_bucket.name}"
  policy_arn = "${aws_iam_policy.data_bucket_writer.arn}"
}





## Role and policies for the log bucket

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

}

resource "aws_iam_policy" "log_bucket_writer" {
  name        = "bucket_writer_${aws_s3_bucket.log_bucket.id}"
  description = "Read or write ${aws_s3_bucket.log_bucket.id}"
  policy      = "${data.aws_iam_policy_document.log_bucket_writer.json}"
}





## Fence bot user
#resource "aws_iam_user" "fence-bot" {
#  name = "${var.vpc_name}_fence-bot"
#}

#resource "aws_iam_access_key" "fence-bot_user_key" {
#  user = "${aws_iam_user.fence-bot.name}"
#}



## CloudwatchLog access

resource "aws_iam_role" "cloudtrail_to_clouodwatch_writer" {
  name = "${var.vpc_name}_data-bucket_ct_to_cwl_writer"
  path = "/"

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

data "aws_iam_policy_document" "trail_policy" {
  statement {
    effect    = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    #resources = ["${data.aws_cloudwatch_log_group.logs_destination.arn}"]
    resources = ["${var.cloudwatchlogs_group}"]
  }

}

resource "aws_iam_policy" "trail_writer" {
  name        = "trail_write_to_cwl_${var.environment}"
  description = "Put logs in CWL ${var.environment}"
  policy      = "${data.aws_iam_policy_document.trail_policy.json}"
}

resource "aws_iam_role_policy_attachment" "trail_writer_role" {
  role       = "${aws_iam_role.cloudtrail_to_clouodwatch_writer.name}"
  policy_arn = "${aws_iam_policy.trail_writer.arn}"
}
