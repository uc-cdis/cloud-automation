terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}


module "bucket-lambda-function" {
  source          = "../modules/lambda-function/"
  lambda_function_file         = "${path.module}/../../../files/lambda/test_simple_lambda.py"
  lambda_function_name         = "${var.lambda_function_name}"
  lambda_function_description  = "${var.lambda_function_description}"
  lambda_function_iam_role_arn = "${var.lambda_function_iam_role_arn}"
  lambda_function_env          = "${var.lambda_function_env}"
  lambda_function_timeout      = "${var.lambda_function_timeout}"
  lambda_function_handler      = "test_simple_lambda.lambda_handler"
}
