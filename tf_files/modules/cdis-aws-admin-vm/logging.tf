# We need a bucket so we can upload logs from Elastic Search, logs from the child account, and
# Kinesis stream logs

resource "aws_s3_bucket" "child_account_bucket" {
  bucket = "${var.child_name}_logging"
  acl    = "private"
  tags {
    Environment  = "${var.child_name}"
    Organization = "Basic Service"
  }
}

############################ Start Kinesis Stream and destination #################
## This is all for the stream of logs that'll be send over from the child account

resource "aws_kinesis_stream" "child_stream" {
    name = "${var.child_name}"
    shard_count = 1
    tags {
        Environment = "${var.child_name}"
        Organization = "Basic Service"
    }
}


resource "aws_iam_role" "cwl_to_kinesis_role" {
  name = "${var.child_name}_cwl_to_kinesis_role"
  path = "/"

  # https://www.terraform.io/docs/providers/aws/r/iam_role_policy.html
  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": {
    "Effect": "Allow",
    "Principal": {
      "Service": "logs.${var.aws_region}.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }
}
EOF
}


# lets allow incoming logs to assume the role that logs can push stuff into kinesis
#
data "aws_iam_policy_document" "cwltok_policy_document" {
  statement {
    actions = ["kinesis:PutRecord"]
    effect    = "Allow"
    resources = ["${aws_kinesis_stream.child_stream.arn}"]
                #["arn:aws:kinesis:${var.aws_region}:${var.csoc_account_id}:stream/${aws_kinesis_stream.child_stream.name}"]
  },

  statement {
    actions = ["iam:PassRole"]
    effect    = "Allow"
    resources = ["${aws_iam_role.cwl_to_kinesis_role.arn}"]
                #["arn:aws:iam::${var.csoc_account_id}:role/${aws_iam_role.child_cwl_to_kinesis_role.name}"]
  }
}

resource "aws_iam_role_policy" "cwltok_policy" {
  name   = "${var.child_name}_cwltok_policy"
  policy = "${data.aws_iam_policy_document.cwltok_policy_document.json}"
  role   = "${aws_iam_role.cwl_to_kinesis_role.id}"
}

# Let's create the destination for the logs to come and put them into kinesis
resource "aws_cloudwatch_log_destination" "child_logs_destination" {
  name = "${var.child_name}_logs_destination"
  role_arn = "${aws_iam_role.cwl_to_kinesis_role.arn}"
  target_arn = "${aws_kinesis_stream.child_stream.arn}"
}

data "aws_iam_policy_document" "child_logs_destination_policy" {
  statement {
    effect = "Allow"
    principals = {
      type = "AWS"
      identifiers = [
        "${var.child_account_id}",
      ]
    }
    actions = [
      "logs:PutSubscriptionFilter",
    ]
    resources = [
      "${aws_cloudwatch_log_destination.child_logs_destination.arn}" ,
    ]
  }
}

resource "aws_cloudwatch_log_destination_policy" "child_logs_destination_poplicy" {
  destination_name = "${aws_cloudwatch_log_destination.child_logs_destination.name}"
  access_policy = "${data.aws_iam_policy_document.child_logs_destination_policy.json}"
}


############################ End Kinesis Stream and destination #################


############################ Begin Kinesis Firehose #############################

#Not sure if we need this, this should be already created and working
# however instructions uses it and this doesn't look like it would actually create domain though
#resource "aws_elasticsearch_domain" "elasticsearch_domain" {
#  domain_name = "${var.elasticsearch_domain}"
#}


resource "aws_iam_role" "firehose_role" {
  name = "${var.child_name}_firehose_role"
  path   = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "firehose_policy_document" {
  statement {
    actions = [
      "s3:ListBucketMultipartUploads",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:GetObject",
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "logs:PutLogEvents"
    ]
    effect    = "Allow"
    resources = [
      "arn:aws:logs:${var.aws_region}:${var.csoc_account_id}:log-group:${var.child_name}:log-stream:*",
      "${aws_s3_bucket.child_account_bucket.arn}",
      "${aws_s3_bucket.child_account_bucket.arn}/*"
    ]
  }

  statement {
    actions = [
      "es:DescribeElasticsearchDomain",
      "es:ListDomainNames",
      "es:DescribeElasticsearchDomain",
      "es:ESHttpPost",
      "es:ESHttpPut",
    ]
    effect    = "Allow"
    resources = ["arn:aws:es:${var.aws_region}:${var.csoc_account_id}:domain/${var.elasticsearch_domain}"]
#"${aws_elasticsearch_domain.elasticsearch_domain.arn}"]
  }
}


resource "aws_iam_role_policy" "firehose_policy" {
  name   = "${var.child_name}_firehose_policy"
  policy = "${data.aws_iam_policy_document.firehose_policy_document.json}"
  role = "${aws_iam_role.firehose_role.id}"
}


resource "aws_kinesis_firehose_delivery_stream" "firehose_to_es" {
  name        = "${var.child_name}_firehose"
  destination = "elasticsearch"

  s3_configuration {
    role_arn           = "${aws_iam_role.firehose_role.arn}"
    bucket_arn         = "${aws_s3_bucket.child_account_bucket.arn}"
    buffer_size        = 10
    buffer_interval    = 400
    compression_format = "GZIP"
  }

  elasticsearch_configuration {
    domain_arn = "arn:aws:es:${var.aws_region}:${var.csoc_account_id}:domain/${var.elasticsearch_domain}" 
#"${aws_elasticsearch_domain.elasticsearch_domain.arn}"
    role_arn   = "${aws_iam_role.firehose_role.arn}"
    index_name = "${var.child_name}"
    type_name  = "${var.child_name}"
  }
}

############################ End Kinesis Firehose #############################

############################ Begin Lambda function  #############################


resource "aws_iam_role" "lambda_role" {
  name = "${var.child_name}_lambda"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "lamda_policy_document" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    effect    = "Allow"
    resources = ["${aws_cloudwatch_log_group.child_log_group.arn}"]
  }

  statement {
    actions = [
      "kinesis:Get*",
      "kinesis:List*",
      "kinesis:Describe*"
    ]
    effect    = "Allow",
    resources = ["${aws_kinesis_stream.child_stream.arn}"]
  }

#  statement {
#    actions = [
#      "ec2:CreateNetworkInterface",
#      "ec2:DescribeNetworkInterfaces",
#      "ec2:DeleteNetworkInterface"
#    ]
#    effect    = "Allow"
#    resources = "*"
#  }

  statement {
    actions = [
      "firehose:PutRecordBatch",
      "firehose:PutRecord",
    ]
    effect    = "Allow"
    resources = ["${aws_kinesis_firehose_delivery_stream.firehose_to_es.arn}"]
  }
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.child_name}_lambda_policy"
  policy = "${data.aws_iam_policy_document.lamda_policy_document.json}"
  role = "${aws_iam_role.lambda_role.id}"
}

resource "aws_lambda_event_source_mapping" "event_source_mapping" {
  batch_size        = 100
  event_source_arn  = "${aws_kinesis_stream.child_stream.arn}"
  enabled           = true
  function_name     = "${aws_lambda_function.logs_decodeding.arn}"
  starting_position = "LATEST"
}

resource "aws_lambda_function" "logs_decodeding" {
#  filename         = "lambda_function_payload.zip"
  filename         = "lambda_function.py"
  function_name    = "${var.child_name}_lambda_function"
  role             = "${aws_iam_role.lambda_role.arn}"
  handler          = "lambda_function.handler"
#  source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  runtime          = "python3.6"
  timeout          = 60
  tracing_config {
    mode           = "PassThrough"
  }
  
  environment {
    variables = {
      stream_name = "${var.child_name}_firehose"
    }
  }
}


############################ End Lambda function  ############################

