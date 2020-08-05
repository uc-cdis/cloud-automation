terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}


module "commons_vpc_es" {
  source                  = "../modules/commons-vpc-es"
  vpc_name                = "${var.vpc_name}"
  slack_webhook           = "${var.slack_webhook}"
  secondary_slack_webhook = "${var.secondary_slack_webhook}"
  instance_type           = "${var.instance_type}"
  ebs_volume_size_gb      = "${var.ebs_volume_size_gb}"
  encryption              = "${var.encryption}"
  instance_count          = "${var.instance_count}"
  organization_name       = "${var.organization_name}"
  es_version              = "${var.es_version}"
  es_linked_role          = "${var.es_linked_role}"
}

