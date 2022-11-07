terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}

data "aws_iam_policy_document" "queue-access-policy" {
  statement {
    actions = [
      "sqs:ReceiveMessage",
      "sqs:GetQueueAttributes",
      "sqs:DeleteMessage"
    ]
    resources = [module.queue.sqs-arn]
  }

  depends_on = [module.queue]
}

module "queue" {
  source        = "../sqs"
  sqs_name      = var.sqs_name
  slack_webhook = var.slack_webhook
}

module "iam-policy" {
  source             = "../iam-policy"
  policy_name        = var.policy_name
  policy_path        = var.policy_path
  policy_description = var.policy_description
  policy_json        = "${data.aws_iam_policy_document.queue-access-policy.json}"
}

module "iam-role" {
  source                = "../iam-role"
  role_name                  = var.role_name
  role_description           = var.role_description 
  role_force_detach_policies = var.role_force_detach_policies
  role_tags                  = var.role_tags
  role_assume_role_policy    = jsonencode(
    {
      "Version": "2012-10-17",
      "Statement": [
      {
        "Effect": "Allow",
        "Principal": {"Service": "ec2.amazonaws.com"},
        "Action": "sts:AssumeRole"
      },
      {
        "Sid": "",
        "Effect": "Allow",
        "Principal": {
          "Federated": "${var.provider_arn}"
        },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {
          "StringEquals": {
            "${var.issuer_url}:aud": "sts.amazonaws.com",
            "${var.issuer_url}:sub": "system:serviceaccount:${var.namespace}:${var.service_account}"
            }
          }
        }
      ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = var.role_name
  policy_arn = module.iam-policy.arn

  depends_on = [module.iam-policy]
}

