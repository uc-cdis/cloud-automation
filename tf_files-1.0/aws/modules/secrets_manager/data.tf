###############
# Collect data
###############

data "aws_caller_identity" "current" {}

# collect vpc_security_group_ids  from vpc_id and security group name
data "aws_vpcs" "vpcs" {
  tags = {
    Name = var.vpc_name
  }
}

data "aws_security_group" "private" {
  vpc_id = data.aws_vpc.the_vpc.id
  name   = "local"
}

data "aws_vpc" "the_vpc" {
  id = data.aws_vpcs.vpcs.ids[0]
}

data "aws_iam_policy_document" "policy" {
  statement {
    sid    = "AllowAccessToSecretsManager"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:${var.role}"]
    }

    actions   = ["secretsmanager:DescribeSecret","secretsmanager:GetSecretValue","secretsmanager:ListSecretVersionIds"]
    resources = ["*"]
  }
}