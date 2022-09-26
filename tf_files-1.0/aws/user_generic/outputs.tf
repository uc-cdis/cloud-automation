output "key_id" {
  value = aws_iam_access_key.generic_user_access_key.id
}
output "key_secret" {
  value     = aws_iam_access_key.generic_user_access_key.secret
  sensitive = true
}
