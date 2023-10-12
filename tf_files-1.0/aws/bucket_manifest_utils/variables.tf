

variable "lambda_function_file" {
  description = "Path to the function file"
}

variable "lambda_function_name" {
  description = "Name of the function you are creating"
}

variable "lambda_function_description" {
  description = "Description of the function"
  default     = ""
}

variable "lambda_function_iam_role_arn" {
  description = "IAM role ARN to attach to the function"
}

variable "lambda_function_handler" {
  description = "Function handler"
  default     = "lambda_funtion.handler"
}

variable "lambda_function_runtime" {
  description = "Language the function will use"
  default     = "python3.7"
}

variable "lambda_function_timeout" {
  description = "Timeout of the function in seconds"
  default     = 3
}

variable "lambda_function_memory_size" {
  description = "How much RAM in MB will be used"
  default     = 128 
}

variable "lambda_function_env" {
  description = "Environmental variables for the funtion"
  default     = {}
}

variable "lambda_function_tags" {
  description = "Tags for the function"
  default     = {}
}


variable "lambda_function_with_vpc" {
  description = "Will the function be attached to a vpc"
  default     = false
}

variable "lambda_function_security_groups" {
  description = "Security groups for the lambda function with a vpc"
  default     = []
}

variable "lambda_function_subnets_id" {
  description = "Subnets for the lambda function with a vpc"
  default     = []
}
