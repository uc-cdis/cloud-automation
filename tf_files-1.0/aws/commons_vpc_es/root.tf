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

module "commons_vpc_es" {
  count                   = var.deploy_es ? 1 : 0
  source                  = "../modules/commons-vpc-es"
  vpc_name                = var.vpc_name
  vpc_id                  = var.vpc_id
  instance_type           = var.instance_type
  ebs_volume_size_gb      = var.ebs_volume_size_gb
  encryption              = var.encryption
  instance_count          = var.instance_count
  organization_name       = var.organization_name
  es_version              = var.es_version
  es_linked_role          = var.es_linked_role
}
