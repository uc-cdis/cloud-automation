terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}


module "commons_sns" {
  source          = "../modules/commons-sns"
  vpc_name        = "${var.vpc_name}"
  emails          = "${var.emails}"
  topic_display   = "${var.topic_display}"
  cluster_type    = "${var.cluster_type}"
}

