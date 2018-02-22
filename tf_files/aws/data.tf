data "aws_availability_zones" "available" {
}

data "aws_iam_policy_document" "kube_provisioner" {
    statement {
      effect = "Allow"
      actions = [
          "acm:*",
      ]
      resources = [ "*" ]
    }
    
    statement {
      effect = "Allow"
      actions = [
        "route53:*",
        "route53domains:*",
        "cloudfront:ListDistributions",
        "sns:ListTopics",
        "sns:ListSubscriptionsByTopic",
      ]
      resources = [ "*" ]
    }
    
    statement {
      effect = "Allow"
      actions = [
        "kms:CreateAlias",
        "kms:CreateKey",
        "kms:DeleteAlias",
        "kms:Describe*",
        "kms:GenerateRandom",
        "kms:Get*",
        "kms:List*",
        "kms:TagResource",
        "kms:UntagResource",
        "kms:EnableKeyRotation",
        "kms:Encrypt",
        "kms:Decrypt",
      ]
      resources = [ "*" ]
    }
    
    statement {
      effect = "Allow"
      actions = [ "s3:*" ]
      resources = [ "*" ]
    }
    statement {
      actions = [ "ec2:*" ]
      effect = "Allow"
      resources = [ "*" ]
    }
    statement {
      effect = "Allow"
      actions = [ "cloudformation:*" ]
      resources = [ "*" ]
    }

    statement {
      effect = "Allow"
      actions = [
          "ecr:*",
          "cloudtrail:LookupEvents"
      ],
      resources = [ "*" ]
    }

    statement {
      effect = "Allow"
      actions = [ "elasticloadbalancing:*" ]
      resources = [ "*" ]
    }

    statement {
      effect = "Allow"
      actions = [ "cloudwatch:*" ]
      resources = [ "*" ]
    }

    statement {
      effect = "Allow"
      actions = [ "autoscaling:*" ]
      resources = [ "*" ]
    }

    statement {
      effect = "Allow"
      actions = [ "iam:*" ]
      resources = [ "*" ]
    }

    statement {
        actions = [
            "sns:ListSubscriptions",
            "sns:ListTopics",
            "sns:Publish",
            "logs:DescribeLogGroups",
            "logs:DescribeLogStreams",
            "logs:GetLogEvents",
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:PutRetentionPolicy",
            "logs:TagLogGroup"
        ]
        effect = "Allow"
        resources = [ "*" ]
    }

    
}
