terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}

# An example of creating lambda function for computing bucket object metadata

# lambda_function_file         = "../../../files/lambda/object_metadata_lambda.py"
# lambda_function_name         = "object_metadata_lambda"
# lambda_function_description  = "generate object metadata function"
# lambda_function_iam_role_arn = "arn:aws:iam::707767160287:role/lambda-generate-metadata"
# lambda_function_timeout      = 10
# lambda_function_handler      = "object_metadata_lambda.lambda_handler"
# lambda_function_env          = {"key1"="value1"}
module "bucket-lambda-function" {
  source          = "../modules/lambda-function/"
  lambda_function_file         = "${path.module}/${var.lambda_function_file}"
  lambda_function_name         = "${var.lambda_function_name}"
  lambda_function_description  = "${var.lambda_function_description}"
  lambda_function_iam_role_arn = "${var.lambda_function_iam_role_arn}"
  lambda_function_env          = "${var.lambda_function_env}"
  lambda_function_timeout      = "${var.lambda_function_timeout}"
  lambda_function_handler      = "${var.lambda_function_handler}"
  # put other variables here ...
}
