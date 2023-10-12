data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "eks" {
  name = var.vpc_name
}

data "aws_secretsmanager_secret" "aurora-master-password" {
  name = "${var.vpc_name}_aurora-master-password"
}


data "aws_secretsmanager_secret_version" "aurora-master-password" {
  secret_id = data.aws_secretsmanager_secret.aurora-master-password.id
}

data "aws_iam_policy_document" "policy" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]

    resources = [
      module.secrets_manager[0].secret-arn,
    ]
  }
}

data "aws_iam_policy_document" "sa_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.eks_oidc_issuer}"
      ]
    }

    # Limit the scope so that only our desired service account can assume this role
    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_issuer}:sub"
      values = [
        "system:serviceaccount:${local.sa_namespace}:${local.sa_name}"
      ]
    }
  }
}

data "aws_db_instance" "database" {
  db_instance_identifier = "${var.vpc_name}-aurora-cluster-instance"
}
