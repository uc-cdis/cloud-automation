# Daily Billing Email Lambda Function

## Overview

This Lambda function sends a daily email report of your current AWS month-to-date charges via SNS. The report includes:

- Total month-to-date cost
- Cost breakdown by AWS service
- Top 15 services by cost with percentages

## Files

- `daily_billing_email.py` - Main Lambda function code

## Requirements

### IAM Permissions

The Lambda execution role needs the following permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ce:GetCostAndUsage"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sns:Publish"
      ],
      "Resource": "arn:aws:sns:REGION:ACCOUNT_ID:TOPIC_NAME"
    },
    {
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
```

### Environment Variables

- `SNS_TOPIC_ARN` - ARN of the SNS topic to send billing notifications

## Deployment

### Step 1: Create SNS Topic and Subscribe Email

You can use the existing `commons-sns` Terraform module:

```hcl
module "billing_alerts_sns" {
  source         = "../modules/commons-sns"
  vpc_name       = "billing-alerts"
  topic_display  = "Daily AWS Billing Reports"
  emails         = ["your-email@example.com"]
}
```

Or create manually:

```bash
# Create SNS topic
aws sns create-topic --name daily-billing-alerts

# Subscribe your email
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:123456789012:daily-billing-alerts \
  --protocol email \
  --notification-endpoint your-email@example.com

# Confirm subscription via email
```

### Step 2: Deploy Lambda Function

Using the existing `lambda-function` Terraform module:

```hcl
# Create IAM role for Lambda
module "billing_lambda_role" {
  source = "../modules/iam-role"

  role_name               = "daily-billing-lambda-role"
  role_description        = "Role for daily billing email Lambda function"
  role_assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Attach Cost Explorer and SNS permissions
resource "aws_iam_role_policy" "billing_lambda_policy" {
  name = "daily-billing-lambda-policy"
  role = module.billing_lambda_role.role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ce:GetCostAndUsage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = module.billing_alerts_sns.topic_arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Deploy Lambda function
module "daily_billing_lambda" {
  source = "../modules/lambda-function"

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
```

### Step 3: Schedule Daily Execution

Use CloudWatch Events to trigger the Lambda daily:

```hcl
# Create CloudWatch Event Rule for daily trigger
resource "aws_cloudwatch_event_rule" "daily_billing_schedule" {
  name                = "daily-billing-email-schedule"
  description         = "Trigger daily billing email at 9 AM UTC"
  schedule_expression = "cron(0 9 * * ? *)"
}

# Add Lambda as target
resource "aws_cloudwatch_event_target" "daily_billing_target" {
  rule      = aws_cloudwatch_event_rule.daily_billing_schedule.name
  target_id = "DailyBillingLambda"
  arn       = module.daily_billing_lambda.lambda_function_arn
}

# Grant CloudWatch Events permission to invoke Lambda
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = module.daily_billing_lambda.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_billing_schedule.arn
}
```

### Manual Deployment (AWS CLI)

If you prefer to deploy manually:

```bash
# Package the Lambda function
cd /home/user/cloud-automation/files/lambda
zip daily_billing_email.zip daily_billing_email.py

# Create the Lambda function
aws lambda create-function \
  --function-name daily-billing-email \
  --runtime python3.9 \
  --role arn:aws:iam::ACCOUNT_ID:role/daily-billing-lambda-role \
  --handler daily_billing_email.lambda_handler \
  --zip-file fileb://daily_billing_email.zip \
  --timeout 30 \
  --memory-size 256 \
  --environment Variables="{SNS_TOPIC_ARN=arn:aws:sns:REGION:ACCOUNT_ID:daily-billing-alerts}"

# Create CloudWatch Event Rule (daily at 9 AM UTC)
aws events put-rule \
  --name daily-billing-email-schedule \
  --schedule-expression "cron(0 9 * * ? *)"

# Add Lambda as target
aws events put-targets \
  --rule daily-billing-email-schedule \
  --targets "Id"="1","Arn"="arn:aws:lambda:REGION:ACCOUNT_ID:function:daily-billing-email"

# Grant permission for CloudWatch Events to invoke Lambda
aws lambda add-permission \
  --function-name daily-billing-email \
  --statement-id AllowExecutionFromCloudWatch \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:REGION:ACCOUNT_ID:rule/daily-billing-email-schedule
```

## Configuration

### Schedule Customization

The cron expression `cron(0 9 * * ? *)` runs daily at 9:00 AM UTC. You can customize this:

- `cron(0 14 * * ? *)` - 2:00 PM UTC (9:00 AM EST)
- `cron(0 0 * * ? *)` - Midnight UTC
- `cron(0 12 * * ? *)` - Noon UTC

**Note:** CloudWatch Events uses UTC time zone.

### Function Configuration

You can adjust the Lambda function settings in the Terraform module or AWS Console:

- **Timeout**: Default 30 seconds (usually completes in 5-10 seconds)
- **Memory**: Default 256 MB (128 MB may be sufficient for smaller accounts)
- **Runtime**: Python 3.9 or higher recommended

## Testing

### Test the Lambda Function

```bash
# Invoke the function manually
aws lambda invoke \
  --function-name daily-billing-email \
  --payload '{}' \
  response.json

# Check the response
cat response.json
```

### Test Locally

```bash
# Set environment variables
export SNS_TOPIC_ARN="arn:aws:sns:us-east-1:123456789012:daily-billing-alerts"

# Run with Python
python3 -c "
import daily_billing_email
result = daily_billing_email.lambda_handler({}, None)
print(result)
"
```

## Email Report Format

The email will look like this:

```
Subject: AWS Billing Report - October 31, 2025

AWS Billing Report for October 2025
Report Date: 2025-10-31
============================================================

Total Month-to-Date Cost: $1,234.56

Cost Breakdown by Service:
------------------------------------------------------------
  Amazon Elastic Compute Cloud                 $   456.78 ( 37.0%)
  Amazon Simple Storage Service                $   234.56 ( 19.0%)
  Amazon Relational Database Service           $   123.45 ( 10.0%)
  Amazon Virtual Private Cloud                 $    89.01 (  7.2%)
  AWS Lambda                                   $    67.89 (  5.5%)
  ...
------------------------------------------------------------

Note: This report shows charges from October 1, 2025 to October 31, 2025
Final charges may vary based on usage throughout the rest of the month.
```

## Troubleshooting

### No Email Received

1. Check SNS subscription is confirmed (check your email for confirmation)
2. Verify Lambda execution in CloudWatch Logs
3. Check Lambda has correct SNS_TOPIC_ARN environment variable
4. Verify IAM permissions for SNS publish

### Cost Explorer Errors

- Ensure IAM role has `ce:GetCostAndUsage` permission
- Cost Explorer must be enabled in your AWS account
- Billing data may have a 24-hour delay

### Lambda Timeout

- Increase timeout if Cost Explorer API is slow
- Default 30 seconds should be sufficient for most accounts

## Cost Considerations

- **Lambda**: Minimal cost (~$0.00 per month with free tier)
- **SNS**: $0.00 for email notifications within free tier
- **Cost Explorer API**: First request is free, subsequent requests are $0.01 each
  - Running daily = ~$0.30 per month

## Security Best Practices

1. Use least-privilege IAM permissions
2. Restrict SNS topic access
3. Enable CloudWatch Logs for monitoring
4. Use VPC endpoints if Lambda is in VPC
5. Rotate credentials regularly
6. Review billing alerts for anomalies

## Additional Resources

- [AWS Cost Explorer API Documentation](https://docs.aws.amazon.com/aws-cost-management/latest/APIReference/API_GetCostAndUsage.html)
- [AWS Lambda Python Documentation](https://docs.aws.amazon.com/lambda/latest/dg/lambda-python.html)
- [AWS SNS Documentation](https://docs.aws.amazon.com/sns/latest/dg/welcome.html)
- [CloudWatch Events Schedule Expressions](https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/ScheduledEvents.html)
