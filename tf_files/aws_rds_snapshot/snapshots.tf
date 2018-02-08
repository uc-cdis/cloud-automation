terraform {
    backend "s3" {
        encrypt = "true"
    }
}

provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region = "${var.aws_region}"
}

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
