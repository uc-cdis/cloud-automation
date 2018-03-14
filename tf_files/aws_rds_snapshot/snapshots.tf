terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}

resource "aws_db_snapshot" "indexd" {
  db_instance_identifier = "${var.indexd_rds_id}"
  db_snapshot_identifier = "${var.vpc_name}-indexd"
}

resource "aws_db_snapshot" "fence" {
  db_instance_identifier = "${var.fence_rds_id}"
  db_snapshot_identifier = "${var.vpc_name}-fence"
}

resource "aws_db_snapshot" "sheepdog" {
  db_instance_identifier = "${var.sheepdog_rds_id}"
  db_snapshot_identifier = "${var.vpc_name}-sheepdog"
}
