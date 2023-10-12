output "fence-bot_secret" {
  value = aws_iam_access_key.fence-bot_user_key.secret
}

output "fence-bot_id" {
  value = aws_iam_access_key.fence-bot_user_key.id
}
