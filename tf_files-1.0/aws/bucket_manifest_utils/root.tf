terraform {
  backend "s3" {
    encrypt = "true"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

module "bucket-lambda-function" {
  source                       = "../modules/lambda-function/"
  lambda_function_file         = "${path.module}/${var.lambda_function_file}"
  lambda_function_name         = var.lambda_function_name
  lambda_function_description  = var.lambda_function_description
  lambda_function_iam_role_arn = var.lambda_function_iam_role_arn
  lambda_function_env          = var.lambda_function_env
  lambda_function_timeout      = var.lambda_function_timeout
  lambda_function_handler      = var.lambda_function_handler
}
