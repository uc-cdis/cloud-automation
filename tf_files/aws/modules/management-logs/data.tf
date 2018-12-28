
data "aws_region" "current" {
  provider = "aws.region"
}

data "aws_caller_identity" "current" {}
