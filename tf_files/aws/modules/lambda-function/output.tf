
output "function_arn" {
  value = "${aws_lambda_function.lambda_function.*.arn}"
}

output "function_name" {
  value = "${aws_lambda_function.lambda_function.*.function_name}"
}


output "function_with_vpc_arn" {
  value = "${aws_lambda_function.lambda_function_with_vpc.*.arn}"
}

output "function_with_vpc_name" {
  value = "${aws_lambda_function.lambda_function_with_vpc.*.function_name}"
}
