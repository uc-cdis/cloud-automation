# We need a bucket so we can upload logs from Elastic Search, logs from the child account, and
# Kinesis stream logs

resource "aws_s3_bucket" "management-logs_bucket" {
  bucket = "management-logs-remote-accounts"

  tags = {
    Environment  = "ALL"
    Organization = "CTDS"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "management-logs_bucket" {
  bucket = aws_s3_bucket.management-logs_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_acl" "management-logs_bucket" {
  bucket = aws_s3_bucket.management-logs_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_lifecycle_configuration" "management-logs_bucket" {
  bucket = aws_s3_bucket.management-logs_bucket.id
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
      days          = 120
      storage_class = "GLACIER"
    }

    expiration {
      days = 1827
    }
  }
}


############################ Start Kinesis Stream and destination #################

resource "aws_kinesis_stream" "management-logs_stream" {
  name        = "management-logs_stream"
  shard_count = 1

  tags = {
    Environment  = "ALL"
    Organization = "CTDS"
  }
}

resource "aws_iam_role" "management-logs_kinesis_role" {
  name = "management-logs_kinesis_role"
  path = "/"

  # https://www.terraform.io/docs/providers/aws/r/iam_role_policy.html
  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": {
    "Effect": "Allow",
    "Principal": {
      "Service": "logs.${data.aws_region.current.name}.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }
}
EOF
}

resource "aws_iam_role_policy" "management-logs_kinesis_policy" {
  name   = "management-logs_kinesis_policy"
  policy = data.aws_iam_policy_document.management-logs_kinesis_policy.json
  role   = aws_iam_role.management-logs_kinesis_role.id
}

# Let's create the destination for the logs to come and put them into kinesis
resource "aws_cloudwatch_log_destination" "management-logs_logs_destination" {
  name       = "management-logs_logs_destination"
  role_arn   = aws_iam_role.management-logs_kinesis_role.arn
  target_arn = aws_kinesis_stream.management-logs_stream.arn
}

resource "aws_cloudwatch_log_destination_policy" "management-logs_logs_destination_policy" {
  destination_name = aws_cloudwatch_log_destination.management-logs_logs_destination.name
  access_policy    = data.aws_iam_policy_document.management-logs_logs_destination_policy.json
}

############################ End Kinesis Stream and destination #################

############################ Begin Kinesis Firehose #############################


resource "aws_iam_role" "firehose_role" {
  name               = "management-logs_firehose_role"
  path               = "/"
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
          "sts:ExternalId": "${data.aws_caller_identity.current.account_id}"
        }
      }
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "firehose_policy_document" {
  statement {
    actions = ["s3:ListBucketMultipartUploads","s3:ListBucket","s3:PutObject","s3:GetObject","s3:AbortMultipartUpload","s3:GetBucketLocation"]
    effect = "Allow"
    resources = [aws_s3_bucket.management-logs_bucket.arn, "${aws_s3_bucket.management-logs_bucket.arn}/*"]
  }

  statement {
    actions = ["logs:*"]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    actions = ["es:*"]
    effect = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "firehose_policy" {
  name   = "management-logs_firehose_policy"
  policy = data.aws_iam_policy_document.firehose_policy_document.json
  role   = aws_iam_role.firehose_role.id
}

# Need these guys because the firehose resource is not that smart to create it if it doesn't exist
# IF and only IF, the firehoses fail executioning they should populate into the group, empty otherwise

resource "aws_cloudwatch_log_group" "management-logs_group" {
  name = "management-logs"
  retention_in_days = 1827

  tags = {
    Environment = "ALL"
    Organization = "CTDS"
  }
}

resource "aws_cloudwatch_log_stream" "firehose_to_ES" {
  name           = "firehose_to_ES"
  log_group_name = aws_cloudwatch_log_group.management-logs_group.name
}

resource "aws_cloudwatch_log_stream" "firehose_to_S3" {
  name           = "firehose_to_S3"
  log_group_name = aws_cloudwatch_log_group.management-logs_group.name
}

## The current requirement is to send these logs onto S3 only, but just commenting in case we want to enable later
resource "aws_kinesis_firehose_delivery_stream" "firehose_to_es" {
  name        = "management-logs_firehose_to_es"
  destination = "elasticsearch"

  s3_configuration {
    role_arn        = aws_iam_role.firehose_role.arn
    bucket_arn      = aws_s3_bucket.management-logs_bucket.arn
    buffer_size     = 10
    buffer_interval = 400
  }

  elasticsearch_configuration {
    domain_arn            = "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.elasticsearch_domain}"
    role_arn              = aws_iam_role.firehose_role.arn
    index_name            = "management_logs"
    type_name             = "management_logs"
    index_rotation_period = "OneWeek"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = "management-logs"
      log_stream_name = "firehose_to_ES"
    }
  }
}


resource "aws_kinesis_firehose_delivery_stream" "firehose_to_s3" {
  name        = "management-logs_firehose_to_s3"
  destination = "s3"

  s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.management-logs_bucket.arn
    prefix     = "forwarded_"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = "management-logs"
      log_stream_name = "firehose_to_S3"
    }
  }
}

############################ End Kinesis Firehose #############################

############################ Begin Lambda function  #############################

resource "aws_iam_role" "lambda_role" {
  name               = "management-logs_lambda_role"
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
  name   = "management-logs_lambda_policy"
  policy = data.aws_iam_policy_document.lambda_policy_document.json
  role   = aws_iam_role.lambda_role.id
}

resource "aws_lambda_event_source_mapping" "event_source_mapping" {
  batch_size        = 100
  event_source_arn  = aws_kinesis_stream.management-logs_stream.arn
  enabled           = true
  function_name     = aws_lambda_function.logs_decoding.arn
  starting_position = "TRIM_HORIZON"
}

# Let's not use the zip file and have teraraform zip it for us on the fly

resource "aws_lambda_function" "logs_decoding" {
  filename         = data.archive_file.lambda_function.output_path
  function_name    = "management-logs_lambda_function"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.handler"
  source_code_hash = data.archive_file.lambda_function.output_base64sha256
  description      = "Decode incoming stream"
  runtime          = "python3.6"
  timeout          = 60

  tracing_config {
    mode = "PassThrough"
  }

  environment {
    variables = {
      stream_name = "management-logs_firehose"
    }
  }
}

############################ End Lambda function  ############################
