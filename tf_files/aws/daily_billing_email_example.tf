#
# Terraform configuration example for deploying the daily billing email Lambda function
#
# This example demonstrates how to deploy the daily billing email Lambda function
# using the existing cloud-automation Terraform modules.
#
# Usage:
#   1. Copy this file to your terraform directory
#   2. Update the variables (email, vpc_name, etc.)
#   3. Run: terraform init && terraform plan && terraform apply
#

# Variables
variable "billing_alert_email" {
  description = "Email address to receive daily billing reports"
  type        = string
  default     = "your-email@example.com"
}

variable "billing_alert_vpc_name" {
  description = "VPC name for SNS topic naming"
  type        = string
  default     = "billing-alerts"
}

variable "billing_alert_schedule" {
  description = "Cron expression for daily billing email (UTC timezone)"
  type        = string
  default     = "cron(0 9 * * ? *)" # 9 AM UTC daily
}

#
# SNS Topic for Billing Alerts
#
module "billing_alerts_sns" {
  source = "./modules/commons-sns"

  vpc_name      = var.billing_alert_vpc_name
  topic_display = "Daily AWS Billing Reports"
  emails        = [var.billing_alert_email]
}

#
# IAM Role for Lambda Execution
#
data "aws_iam_policy_document" "billing_lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

module "billing_lambda_role" {
  source = "./modules/iam-role"

  role_name               = "daily-billing-lambda-role"
  role_description        = "Execution role for daily billing email Lambda function"
  role_assume_role_policy = data.aws_iam_policy_document.billing_lambda_assume_role.json
}

#
# IAM Policy for Lambda Function
#
data "aws_iam_policy_document" "billing_lambda_policy" {
  # Cost Explorer permissions
  statement {
    effect = "Allow"
    actions = [
      "ce:GetCostAndUsage"
    ]
    resources = ["*"]
  }

  # SNS publish permissions
  statement {
    effect = "Allow"
    actions = [
      "sns:Publish"
    ]
    resources = [module.billing_alerts_sns.topic_arn]
  }

  # CloudWatch Logs permissions
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role_policy" "billing_lambda_policy" {
  name   = "daily-billing-lambda-policy"
  role   = module.billing_lambda_role.role_id
  policy = data.aws_iam_policy_document.billing_lambda_policy.json
}

#
# Lambda Function
#
module "daily_billing_lambda" {
  source = "./modules/lambda-function"

  lambda_function_file        = "${path.module}/../../files/lambda/daily_billing_email.py"
  lambda_function_name        = "daily-billing-email"
  lambda_function_handler     = "daily_billing_email.lambda_handler"
  lambda_function_runtime     = "python3.9"
  lambda_function_timeout     = 30
  lambda_function_memory_size = 256
  lambda_function_iam_role_arn = module.billing_lambda_role.role_arn

  lambda_function_env = {
    SNS_TOPIC_ARN = module.billing_alerts_sns.topic_arn
  }
}

#
# CloudWatch Event Rule for Daily Trigger
#
resource "aws_cloudwatch_event_rule" "daily_billing_schedule" {
  name                = "daily-billing-email-schedule"
  description         = "Trigger daily billing email Lambda function"
  schedule_expression = var.billing_alert_schedule
}

resource "aws_cloudwatch_event_target" "daily_billing_target" {
  rule      = aws_cloudwatch_event_rule.daily_billing_schedule.name
  target_id = "DailyBillingLambda"
  arn       = module.daily_billing_lambda.lambda_function_arn
}

#
# Lambda Permission for CloudWatch Events
#
resource "aws_lambda_permission" "allow_cloudwatch_invoke" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = module.daily_billing_lambda.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_billing_schedule.arn
}

#
# Outputs
#
output "lambda_function_arn" {
  description = "ARN of the daily billing Lambda function"
  value       = module.daily_billing_lambda.lambda_function_arn
}

output "lambda_function_name" {
  description = "Name of the daily billing Lambda function"
  value       = module.daily_billing_lambda.lambda_function_name
}

output "sns_topic_arn" {
  description = "ARN of the billing alerts SNS topic"
  value       = module.billing_alerts_sns.topic_arn
}

output "cloudwatch_rule_name" {
  description = "Name of the CloudWatch Events rule"
  value       = aws_cloudwatch_event_rule.daily_billing_schedule.name
}

output "billing_alert_email" {
  description = "Email address receiving billing alerts"
  value       = var.billing_alert_email
}
