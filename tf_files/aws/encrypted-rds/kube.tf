terraform {
  backend "s3" {}
}

# Pinning the aws version to avoid a bug in 3.29.0 
# https://github.com/hashicorp/terraform-provider-aws/issues/17712
provider "aws" {
  version = "= 3.28.0"
}

#
# Only create db_fence if var.db_password_fence is set.
# Sort of a hack during userapi to fence switch over.
#
resource "aws_db_instance" "db_fence" {
  count                       = "${var.deploy_fence_db ? 1 : 0}"
  allocated_storage           = "${var.fence_db_size}"
  identifier                  = "${var.vpc_name}-encrypted-fencedb"
  storage_type                = "gp2"
  engine                      = "${var.fence_engine}"
  engine_version              = "${var.fence_engine_version}"
  parameter_group_name        = "${aws_db_parameter_group.rds-cdis-pg.name}"
  instance_class              = "${var.fence_db_instance}"
  name                        = "${var.fence_database_name}"
  username                    = "${var.fence_db_username}"
  password                    = "${var.db_password_fence}"
  snapshot_identifier         = "${var.fence_snapshot}"
  db_subnet_group_name        = "${var.aws_db_subnet_group_name}"
  vpc_security_group_ids      = ["${var.security_group_local_id}"]
  allow_major_version_upgrade = "${var.fence_allow_major_version_upgrade}"
  final_snapshot_identifier   = "${replace(var.vpc_name,"_", "-")}-fencedb"
  maintenance_window          = "${var.fence_maintenance_window}"
  backup_retention_period     = "${var.fence_backup_retention_period}"
  backup_window               = "${var.fence_backup_window}"
  multi_az                    = "${var.fence_ha}"
  auto_minor_version_upgrade  = "${var.fence_auto_minor_version_upgrade}"
  storage_encrypted           = "${var.rds_instance_storage_encrypted}"
  max_allocated_storage       = "${var.fence_max_allocated_storage}"  
  tags = {
    Environment               = "${var.vpc_name}"
    Organization              = "${var.organization_name}"
  }

  lifecycle {
    ignore_changes = ["identifier"]
  }
}

resource "aws_db_instance" "db_gdcapi" {
  count                       = "${var.deploy_sheepdog_db ? 1 : 0}"
  allocated_storage           = "${var.sheepdog_db_size}"
  identifier                  = "${var.vpc_name}-encrypted-gdcapidb"
  storage_type                = "gp2"
  engine                      = "${var.sheepdog_engine}"
  engine_version              = "${var.sheepdog_engine_version}"
  parameter_group_name        = "${aws_db_parameter_group.rds-cdis-pg.name}"
  instance_class              = "${var.sheepdog_db_instance}"
  name                        = "${var.sheepdog_database_name}"
  username                    = "${var.sheepdog_db_username}"
  password                    = "${var.db_password_sheepdog}"
  snapshot_identifier         = "${var.gdcapi_snapshot}"
  db_subnet_group_name        = "${var.aws_db_subnet_group_name}"
  vpc_security_group_ids      = ["${var.security_group_local_id}"]
  allow_major_version_upgrade = "${var.sheepdog_allow_major_version_upgrade}"
  final_snapshot_identifier   = "${replace(var.vpc_name,"_", "-")}-gdcapidb"
  maintenance_window          = "${var.sheepdog_maintenance_window}"
  backup_retention_period     = "${var.sheepdog_backup_retention_period}"
  backup_window               = "${var.sheepdog_backup_window}"
  multi_az                    = "${var.sheepdog_ha}"
  auto_minor_version_upgrade  = "${var.sheepdog_auto_minor_version_upgrade}"
  storage_encrypted           = "${var.rds_instance_storage_encrypted}"
  max_allocated_storage       = "${var.sheepdog_max_allocated_storage}"
  tags = {
    Environment               = "${var.vpc_name}"
    Organization              = "${var.organization_name}"
  }

  lifecycle {
    ignore_changes = ["identifier"]
  }
}

resource "aws_db_instance" "db_indexd" {
  count                       = "${var.deploy_indexd_db ? 1 : 0}"
  allocated_storage           = "${var.indexd_db_size}"
  identifier                  = "${var.vpc_name}-encrypted-indexddb"
  storage_type                = "gp2"
  engine                      = "${var.indexd_engine}"
  engine_version              = "${var.indexd_engine_version}"
  parameter_group_name        = "${aws_db_parameter_group.rds-cdis-pg.name}"
  instance_class              = "${var.indexd_db_instance}"
  name                        = "${var.indexd_database_name}"
  username                    = "${var.indexd_db_username}"
  password                    = "${var.db_password_indexd}"
  snapshot_identifier         = "${var.indexd_snapshot}"
  db_subnet_group_name        = "${var.aws_db_subnet_group_name}"
  vpc_security_group_ids      = ["${var.security_group_local_id}"]
  allow_major_version_upgrade = "${var.indexd_allow_major_version_upgrade}"
  final_snapshot_identifier   = "${replace(var.vpc_name,"_", "-")}-indexddb"
  maintenance_window          = "${var.indexd_maintenance_window}"
  backup_retention_period     = "${var.indexd_backup_retention_period}"
  backup_window               = "${var.indexd_backup_window}"
  multi_az                    = "${var.indexd_ha}"
  auto_minor_version_upgrade  = "${var.indexd_auto_minor_version_upgrade}"
  storage_encrypted           = "${var.rds_instance_storage_encrypted}"
  max_allocated_storage       = "${var.indexd_max_allocated_storage}"
  tags = {
    Environment               = "${var.vpc_name}"
    Organization              = "${var.organization_name}"
  }

  lifecycle {
    ignore_changes = ["identifier"]
  }
}

resource "aws_db_parameter_group" "rds-cdis-pg" {
  name   = "${var.vpc_name}-rds-cdis-pg"
  family = "postgres${var.fence_engine_version}"

  # make index searches cheaper per row
  parameter {
    name  = "cpu_index_tuple_cost"
    value = "0.000005"
  }

  # raise cost of search per row to be closer to read cost
  # suggested for SSD backed disks
  parameter {
    name  = "cpu_tuple_cost"
    value = "0.7"
  }

  # Log the duration of each SQL statement
  parameter {
    name  = "log_duration"
    value = "1"
  }

  # Log statements above this duration
  # 0 = everything
  parameter {
    name  = "log_min_duration_statement"
    value = "0"
  }

  # lower cost of random reads from disk because we use SSDs
  parameter {
    name  = "random_page_cost"
    value = "0.7"
  }

  # Set the scram password encryption so that connecting with FIPs enabled works
  parameter {
    name  = "password_encryption"
    value = "scram-sha-256"
  }

  lifecycle {
    ignore_changes  = ["*"]
  }
}

# See https://www.postgresql.org/docs/9.6/static/runtime-config-logging.html
# and https://www.postgresql.org/docs/9.6/static/runtime-config-query.html#RUNTIME-CONFIG-QUERY-ENABLE
# for detail parameter descriptions
