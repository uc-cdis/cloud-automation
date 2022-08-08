module "cloudwatch-events" {
  source               = "../cloudwatch-events/"
  cwe_rule_name        = "${var.account_name}-cloudtrail-StopLogging"
  cwe_rule_description = "Lets check if someone dares to stop logging"
  cwe_target_arn       = element(module.alerting-lambda.function_arn,0)
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
  lambda_function_file         = "${path.module}/../../../../files/lambda/security_alerts.py"
  lambda_function_name         = "${var.account_name}-security-alert-lambda"
  lambda_function_description  = "Checking for things that should or might not happend"
  lambda_function_iam_role_arn = module.role-for-lambda.role_arn
  lambda_function_env          = {"topic"="arn:aws:sns:us-east-1:433568766270:planx-csoc-alerts-for-bsd-security"}
  lambda_function_handler      = "security_alerts.lambda_handler"
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

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = element(module.alerting-lambda.function_name,0)
  principal     = "events.amazonaws.com"
  source_arn    = module.cloudwatch-events.event_arn
  #qualifier    = "${aws_lambda_alias.test_alias.name}"
}

resource "aws_iam_role_policy" "lambda_policy_SNS" {
  name                  = "${var.account_name}-security-alert-policy-for-SNS"
  policy                = data.aws_iam_policy_document.sns_access.json
  role                  = module.role-for-lambda.role_id
}


resource "aws_iam_role_policy" "lambda_policy_CT" {
  name                  = "${var.account_name}-security-alert-policy-for-CloudTrail"
  policy                = data.aws_iam_policy_document.cloudtrail_access.json
  role                  = module.role-for-lambda.role_id
}

resource "aws_iam_role_policy" "lambda_policy_CWL" {
  name                  = "${var.account_name}-security-alert-policy-for-CloudWatchLogs"
  policy                = data.aws_iam_policy_document.cloudwatchlogs_access.json
  role                  = module.role-for-lambda.role_id
}
