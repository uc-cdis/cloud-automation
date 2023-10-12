# We need a bucket so we can upload logs from Elastic Search, logs from the child account, and
# Kinesis stream logs

resource "aws_s3_bucket" "common_logging_bucket" {
  bucket = "${var.common_name}-logging"

  tags = {
    Environment  = var.common_name
    Organization = "Basic Services"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "common_logging_bucket" {
  bucket = aws_s3_bucket.common_logging_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "common_logging_bucket" {
  bucket = aws_s3_bucket.common_logging_bucket.id

  rule {
    status  = "Enabled"
    id      = "forwarded"

    filter {
      and {
        prefix = "forwarded*/"

        tags = {
          rule      = "log"
          autoclean = "true"
        }
      }
    }

    transition {
      days          = 60
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 2190
    }
  }
}


resource "aws_s3_bucket_public_access_block" "data_bucket_privacy" {
  bucket                      = aws_s3_bucket.common_logging_bucket.id
  block_public_acls           = true
  block_public_policy         = true
  ignore_public_acls          = true
  restrict_public_buckets     = true
}

############################ Start Kinesis Stream and destination #################

resource "aws_kinesis_stream" "common_stream" {
  name        = "${var.common_name}_stream"
  shard_count = 1

  tags = {
    Environment  = var.common_name
    Organization = "Basic Services"
  }
}

resource "aws_iam_role" "cwl_to_kinesis_role" {
  name = "${var.common_name}_cwl_to_kinesis_role"
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
    actions   = ["kinesis:PutRecord"]
    effect    = "Allow"
    resources = [aws_kinesis_stream.common_stream.arn]
  }

  statement {
    actions   = ["iam:PassRole"]
    effect    = "Allow"
    resources = [aws_iam_role.cwl_to_kinesis_role.arn]
  }
}

resource "aws_iam_role_policy" "cwltok_policy" {
  name   = "${var.common_name}_cwltok_policy"
  policy = data.aws_iam_policy_document.cwltok_policy_document.json
  role   = aws_iam_role.cwl_to_kinesis_role.id
}

# Let's create the destination for the logs to come and put them into kinesis
resource "aws_cloudwatch_log_destination" "common_logs_destination" {
  name       = "${var.common_name}_logs_destination"
  role_arn   = aws_iam_role.cwl_to_kinesis_role.arn
  target_arn = aws_kinesis_stream.common_stream.arn
}

data "aws_iam_policy_document" "common_logs_destination_policy" {
  statement {
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = [var.child_account_id]
    }
    actions   = ["logs:PutSubscriptionFilter"]
    resources = [aws_cloudwatch_log_destination.common_logs_destination.arn]
  }
}

resource "aws_cloudwatch_log_destination_policy" "common_logs_destination_policy" {
  destination_name = aws_cloudwatch_log_destination.common_logs_destination.name
  access_policy    = data.aws_iam_policy_document.common_logs_destination_policy.json
}

############################ End Kinesis Stream and destination #################

############################ Begin Kinesis Firehose #############################

#Not sure if we need this, this should be already created and working
# however instructions uses it and this doesn't look like it would actually create domain though
#resource "aws_elasticsearch_domain" "elasticsearch_domain" {
#  domain_name = "${var.elasticsearch_domain}"
#}

resource "aws_iam_role" "firehose_role" {
  name = "${var.common_name}_firehose_role"
  path = "/"

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
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "${var.csoc_account_id}"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "firehose_policy" {
  name   = "${var.common_name}_firehose_policy"
  policy = data.aws_iam_policy_document.firehose_policy_document.json
  role   = aws_iam_role.firehose_role.id
}

# Need these guys because the firehose resource is not that smart to create it if it doesn't exist
# IF and only IF, the firehoses fail executioning they should populate into the group, enpty otherwise

resource "aws_cloudwatch_log_group" "csoc_common_log_group" {
  name              = var.common_name
  retention_in_days = 3653

  tags = {
    Environment  = var.common_name
    Organization = "Basic Services"
  }  
}

resource "aws_cloudwatch_log_stream" "firehose_to_ES" {
  name           = "firehose_to_ES"
  log_group_name = aws_cloudwatch_log_group.csoc_common_log_group.name
}

resource "aws_cloudwatch_log_stream" "firehose_to_S3" {
  name           = "firehose_to_S3"
  log_group_name = aws_cloudwatch_log_group.csoc_common_log_group.name
}

resource "aws_kinesis_firehose_delivery_stream" "firehose_to_es" {
  name        = "${var.common_name}_firehose_to_es"
  destination = "elasticsearch"

  s3_configuration {
    role_arn        = aws_iam_role.firehose_role.arn
    bucket_arn      = aws_s3_bucket.common_logging_bucket.arn
    buffer_size     = 10
    buffer_interval = 400
  }

  elasticsearch_configuration {
    domain_arn            = "arn:aws:es:${var.aws_region}:${var.csoc_account_id}:domain/${var.elasticsearch_domain}"
    role_arn              = aws_iam_role.firehose_role.arn
    index_name            = var.common_name
    type_name             = var.common_name
    index_rotation_period = "OneWeek"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = var.common_name
      log_stream_name = "firehose_to_ES"
    }
  }
}

resource "aws_kinesis_firehose_delivery_stream" "firehose_to_s3" {
  name        = "${var.common_name}_firehose_to_s3"
  destination = "s3"

  s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.common_logging_bucket.arn
    prefix     = "forwarded_"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = var.common_name
      log_stream_name = "firehose_to_S3"
    }
  }
}

############################ End Kinesis Firehose #############################

############################ Begin Lambda function  #############################

resource "aws_iam_role" "lambda_role" {
  name               = "${var.common_name}_lambda"
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

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "${var.common_name}_lambda_policy"
  policy = data.aws_iam_policy_document.lambda_policy_document.json
  role   = aws_iam_role.lambda_role.id
}

resource "aws_lambda_event_source_mapping" "event_source_mapping" {
  batch_size        = 100
  event_source_arn  = aws_kinesis_stream.common_stream.arn
  enabled           = true
  function_name     = aws_lambda_function.logs_decoding.arn
  starting_position = "TRIM_HORIZON"
}

# Let's not use the zip file and have terarafor zip it for us on the fly

data "archive_file" "lambda_function" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "lambda_function_payload.zip"
}

resource "aws_lambda_function" "logs_decoding" {
  filename         = data.archive_file.lambda_function.output_path
  function_name    = "${var.common_name}_lambda_function"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.handler"
  source_code_hash = data.archive_file.lambda_function.output_base64sha256
  description      = "Decode incoming log stream"
  runtime          = "python3.6"
  timeout          = var.timeout
  memory_size      = var.memory_size

  tracing_config {
    mode = "PassThrough"
  }

  environment {
    variables = { stream_name = "${var.common_name}_firehose", threshold = var.threshold, slack_webhook = var.slack_webhook, s3 = var.s3, es = var.es }
  }

}

############################ End Lambda function  ############################
