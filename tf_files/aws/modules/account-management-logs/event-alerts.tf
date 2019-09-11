

module "cloudwatch-events" {
  source               = "../cloudwatch-events/"
  cwe_rule_name        = "${var.account_name}-cloudtrail-StopLogging"
  cwe_rule_description = "Lets check if someone dares to stop logging"
  cwe_target_arn       = "${module.alerting-lambda.function_arn}"
  cwe_rule_pattern     = <<EOP
{
  "source": [
    "aws.cloudtrail"
  ],
  "detail": {
    "eventName": [
      "StopLogging"
    ]
  }
}
EOP
}

module "alerting-lambda" {
  source                       = "../lambda-function/"
  function_file                = "${path.module}/../../../../files/lambda/security_alerts.py"
  lambda_function_name         = "${var.account_name}-security-alert-lambda"
  lambda_function_description  = "Checking for things that should or might not happend"
  lambda_function_iam_role_arn = "${module.role-for-lambda.role_arn}"
  lambda_function_env          = {"topic"="arn:aws:sns:us-east-1:433568766270:planx-csoc-alerts-for-bsd-security"}
}

module "role-for-lambda" {
  source                       = "../iam-role/"
  role_name                    = "${var.account_name}-security-alert-role"
  role_description             = "Role for the alerting lambda function"
  role_assume_role_policy      = <<EOP
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOP
}

data "aws_iam_policy_document" "security_alert_policy" {
  statement {
    actions = [
      "SNS:Publish",
      "SNS:sns:GetTopicAttributes"
    ]
    effect = "Allow"
    resources = ["arn:aws:sns:us-east-1:433568766270:planx-csoc-alerts-for-bsd-securitys"]
  }
}


resource "aws_iam_role_policy" "lambda_policy" {
  name                  = "${var.account_name}-security-alert-policy"
  policy                = "${data.aws_iam_policy_document.security_alert_policy.json}"
  role                  = "${module.role-for-lambda.role_id}"
}

resource "aws_iam_role_policy_attachment" "sns-access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
  role       = "${module.role-for-lambda.role_id}"
}
