output "manifest_lambda" {
  value = "${module.bucket-lambda-function.function_arn}"
}