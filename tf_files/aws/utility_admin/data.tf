

data "aws_iam_policy_document" "assume_role_policy_document" {
  statement {
    actions = [ "sts:AssumeRole" ]
    effect    = "Allow"
    resources = ["arn:aws:iam::${var.aws_account_id}:role/csoc_adminvm"]
  }
}

