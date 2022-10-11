# Iam Policy Document
data "aws_iam_policy_document" "hatchery-policy-document" {
  statement {
    effect = "Allow"
    actions= [
        "sts:AssumeRole"
    ]
    resources = [
        "arn:aws:iam::*:role/csoc_adminvm*"
    ]
  }
  statement {
    effect = "Allow"
    actions= [
        "ec2:*"
    ]
    resources = [
        "*"
    ]
  }
  statement {
    sid = "DynamoDB"
    effect = "Allow"
    actions = [
        "dynamodb:BatchGet*",
        "dynamodb:DescribeStream",
        "dynamodb:DescribeTable",
        "dynamodb:Get*",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:BatchWrite*",
        "dynamodb:CreateTable",
        "dynamodb:Delete*",
        "dynamodb:Update*",
        "dynamodb:PutItem"
    ]

    resources = [
      "arn:aws:dynamodb:*:*:table/**"
    ]
  }
}