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
resource "aws_iam_role_policy_attachment" "new_attach" {
  role       = var.role
  policy_arn = var.policy_arn
}
