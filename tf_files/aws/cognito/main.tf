terraform {
  backend "s3" {}
}

provider "aws" {}

resource "aws_cognito_user_pool" "pool" {
  name = "${var.vpc_name}_user_pool"

  tags = var.tags
}


resource "aws_cognito_user_pool_domain" "main" {
  domain       = var.cognito_domain_name
  user_pool_id = aws_cognito_user_pool.pool.id
}



resource "aws_cognito_identity_provider" "provider" {
  user_pool_id      = aws_cognito_user_pool.pool.id
  provider_name     = var.cognito_provider_name
  provider_type     = var.cognito_provider_type
  attribute_mapping = var.cognito_attribute_mapping
  provider_details  = var.cognito_provider_details
}


resource "aws_cognito_user_pool_client" "client" {
  name                                 = var.cognito_user_pool_name
  user_pool_id                         = aws_cognito_user_pool.pool.id

  callback_urls                        = var.cognito_callback_urls
  allowed_oauth_flows_user_pool_client = true
  generate_secret                      = true
  allowed_oauth_flows                  = var.cognito_oauth_flows
  allowed_oauth_scopes                 = var.cognito_oauth_scopes
  supported_identity_providers         = [aws_cognito_identity_provider.provider.provider_name]
}
