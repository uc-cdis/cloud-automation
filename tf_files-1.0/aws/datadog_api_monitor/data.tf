data "aws_secretsmanager_secret" "dd_keys" {
    arn = var.datadog_secrets_manager_arn
}

data "aws_secretsmanager_secret_version" "secrets" {
  secret_id = data.aws_secretsmanager_secret.dd_keys.id
}
