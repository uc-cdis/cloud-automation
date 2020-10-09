
resource "aws_cloudwatch_log_group" "gwl_group" {
  count         = "${var.ha_squid ? 1 : 0}"
  name              = "/aws/lambda/${var.vpc_name}-gw-checks-lambda" 
  retention_in_days = 14
}

module "iam_role" {
  #count         = "${var.ha_squid ? 1 : 0}"
  source                  = "../iam-role"
  role_name               = "${var.vpc_name}-gw-checks-lambda-role"
  role_description        = "Role for ${var.vpc_name}-gw-checks-lambda"
  role_tags               = { Environment  = "${var.vpc_name}"
    Organization = "${var.organization_name}"
  }
  role_assume_role_policy = <<EOF
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

resource "aws_iam_role_policy" "lambda_policy_resources" {
  count         = "${var.ha_squid ? 1 : 0}"
  name                  = "resources_acces"
  policy                = "${data.aws_iam_policy_document.with_resources.json}"
  role                  = "${module.iam_role.role_id}"
}

resource "aws_iam_role_policy" "lambda_policy_no_resources" {
  count         = "${var.ha_squid ? 1 : 0}"
  name                  = "no_resources_acces"
  policy                = "${data.aws_iam_policy_document.without_resources.json}"
  role                  = "${module.iam_role.role_id}"
}


module "iam_policy" {
  #count         = "${var.ha_squid ? 1 : 0}"
  source             = "../iam-policy"
  policy_name        = "${var.vpc_name}-gw-checks-lambda-cwlg"
  policy_path        = "/"
  policy_description = "IAM policy for ${var.vpc_name}-gw-checks-lambda to access CWLG"
  policy_json        = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  count         = "${var.ha_squid ? 1 : 0}"
  role       = "${module.iam_role.role_id}" 
  policy_arn = "${module.iam_policy.arn}" 
}


resource "aws_lambda_function" "gw_checks" {
  count         = "${var.ha_squid ? 1 : 0}"
  filename      = "lambda_function_payload.zip"
  function_name = "${var.vpc_name}-gw-checks-lambda"
  role          = "${module.iam_role.role_arn}" 
  handler       = "lambda_function.lambda_handler"
  timeout       = 45
  description   = "Checks for internet access from the worker nodes subnets"

  vpc_config {
    subnet_ids         = ["${aws_subnet.eks_private.*.id}"]
    security_group_ids = ["${aws_security_group.eks_nodes_sg.id}"]
  }

  tags = {
    Environment  = "${var.vpc_name}"
    Organization = "${var.organization_name}"
  }


  source_code_hash = "${data.archive_file.lambda_function.output_base64sha256}"

  runtime = "python3.8"

  environment {
    variables = {
      vpc_name = "${var.vpc_name}",
      domain_test = "${var.domain_test}"
    }
  }
  depends_on = ["aws_cloudwatch_log_group.gwl_group"]
}



resource "aws_cloudwatch_event_rule" "gw_checks_rule" {
  count         = "${var.ha_squid ? 1 : 0}"
  name                = "${var.vpc_name}-GW-checks-job"
  description         = "Check if the gateway is working every minute"
  schedule_expression = "rate(1 minute)"
  tags = {
    Environment  = "${var.vpc_name}"
    Organization = "${var.organization_name}"
  }
}

resource "aws_cloudwatch_event_target" "cw_to_lambda" {
  count         = "${var.ha_squid ? 1 : 0}"
  rule      = "${aws_cloudwatch_event_rule.gw_checks_rule.name}"
  arn       = "${aws_lambda_function.gw_checks.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  count         = "${var.ha_squid ? 1 : 0}"
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.gw_checks.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.gw_checks_rule.arn}"
}
