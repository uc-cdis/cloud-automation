data "archive_file" "lambda_function" {
  type        = "zip"
  source_file = var.lambda_function_file
  output_path = "lambda_function_payload.zip"
}