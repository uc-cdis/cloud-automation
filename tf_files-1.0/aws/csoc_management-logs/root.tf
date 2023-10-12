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

module "logging" {
  source               = "../modules/management-logs"
  accounts_id          = var.accounts_id
  elasticsearch_domain = var.elasticsearch_domain
}
