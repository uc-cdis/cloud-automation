
resource "aws_secretsmanager_secret" "secret" {
  name = "${var.vpc_name}_${var.secret_name}"
}

resource "aws_secretsmanager_secret_policy" "policy" {
  secret_arn = aws_secretsmanager_secret.secret.arn
  policy     = data.aws_iam_policy_document.policy.json
}

resource "aws_secretsmanager_secret_version" "secret" {
  secret_id     = aws_secretsmanager_secret.secret.id
  secret_string = var.secret
}
