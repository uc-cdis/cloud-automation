
output "cognito_user_pool_id" {
  value = "${aws_cognito_user_pool.pool.id}"
}

output "cognito_domain" {
  value = "${aws_cognito_user_pool_domain.main.domain}"
}

output "cognito_user_pool_client" {
  value = "${aws_cognito_user_pool_client.client.id}"
}

output "cognito_user_pool_client_secret" {
  value = "${aws_cognito_user_pool_client.client.client_secret}"
}
