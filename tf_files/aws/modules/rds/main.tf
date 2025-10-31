

locals {
  is_mssql = "${element(split("-", var.rds_instance_engine), 0) == "sqlserver" ? true : false}"
}

data "aws_iam_policy_document" "enhanced_monitoring" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "enhanced_monitoring" {
  count = "${var.rds_instance_create_monitoring_role ? 1 : 0}"

  name               = "${var.rds_instance_monitoring_role_name}"
  assume_role_policy = "${data.aws_iam_policy_document.enhanced_monitoring.json}"

  tags = "${merge(map("Name", format("%s", var.rds_instance_monitoring_role_name)), var.rds_instance_tags )}"
}

resource "aws_iam_role_policy_attachment" "enhanced_monitoring" {
  count = "${var.rds_instance_create_monitoring_role ? 1 : 0}"

  role       = "${aws_iam_role.enhanced_monitoring.*.name[count.index]}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "random_string" "randommssql" {
  count = "${var.rds_instance_create && local.is_mssql ? 1 : 0}"
  length  = 16
  special = false
}


resource "random_string" "randomother" {
  count = "${var.rds_instance_create && false == local.is_mssql ? 1 : 0}"
  length  = 16
  special = true
}

resource "aws_db_option_group" "rds_instance_new_option_group" {
  #count                    = "${var.rds_instance_option_group_name == "" ? 1 : 0}"
  #count                    = "${var.rds_instance_option_group_name == "" && var.rds_instance_backup_enabled ? 1 : 0}"
  name                     = "${var.rds_instance_identifier}-option-group"
  option_group_description = "Additional options to the database"
  engine_name              = "${var.rds_instance_engine}"
  major_engine_version     = "${local.is_mssql ? substr(var.rds_instance_engine_version,0,5) : var.rds_instance_engine_version}"
  tags                     = "${merge(map("Name", format("%s", var.rds_instance_monitoring_role_name)), var.rds_instance_tags )}"

  option {
    option_name = "SQLSERVER_BACKUP_RESTORE"

    option_settings {
      name  = "IAM_ROLE_ARN"
      value = "${aws_iam_role.rds_backup_role.arn}"
    }
  }
}



## Role for backup

resource "aws_iam_role" "rds_backup_role" {
  #count = "${var.rds_instance_option_group_name == "" && var.rds_instance_backup_enabled ? 1 : 0}"
  name  = "${var.rds_instance_identifier}-backup-role"
  tags  = "${merge(map("Name", format("%s", var.rds_instance_monitoring_role_name)), var.rds_instance_tags )}"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "rds.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}


data "aws_iam_policy_document" "backup_bucket_access_kms" {
  #count       = "${var.rds_instance_backup_enabled ? 1 : 0}"
  statement {
    actions = [
        "kms:DescribeKey",
        "kms:GenerateDataKey",
        "kms:Encrypt",
        "kms:Decrypt"
      ]
    resources = ["arn:aws:kms:region:${data.aws_caller_identity.current.account_id}:key/${var.rds_instance_backup_kms_key}"]
    effect = "Allow"
  }

  statement {
    actions = [
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ]
    resources = ["arn:aws:s3:::${var.rds_instance_backup_bucket_name}"]
    effect = "Allow"
  }

  statement {
    actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListMultipartUploadParts",
        "s3:AbortMultipartUpload"
      ]
    resources = ["arn:aws:s3:::${var.rds_instance_backup_bucket_name}"]
    effect = "Allow"
  }
}


resource "aws_iam_role_policy" "backup_bucket_access" {
  #count  = "${var.rds_instance_backup_enabled ? 1 : 0}"
  name   = "${var.rds_instance_identifier}_backup_bucket_access"
  policy = "${data.aws_iam_policy_document.backup_bucket_access_kms.json}"
  role   = "${aws_iam_role.rds_backup_role.id}"
}


resource "aws_db_instance" "this" {
  count = "${var.rds_instance_create && false == local.is_mssql ? 1 : 0}"

  identifier                            = "${var.rds_instance_identifier}"

  engine                                = "${var.rds_instance_engine}"
  engine_version                        = "${var.rds_instance_engine_version}"
  instance_class                        = "${var.rds_instance_instance_class}"
  allocated_storage                     = "${var.rds_instance_allocated_storage}"
  storage_type                          = "${var.rds_instance_storage_type}"
  storage_encrypted                     = "${var.rds_instance_storage_encrypted}"
  kms_key_id                            = "${var.rds_instance_kms_key_id}"
  license_model                         = "${var.rds_instance_license_model}"

  name                                  = "${var.rds_instance_name}"
  username                              = "${var.rds_instance_username}"
  password                              = "${var.rds_instance_password == "" ? random_string.randomother.*.result[count.index] : var.rds_instance_password}"
  port                                  = "${var.rds_instance_port}"
  iam_database_authentication_enabled   = "${var.rds_instance_iam_database_authentication_enabled}"

  replicate_source_db                   = "${var.rds_instance_replicate_source_db}"

  snapshot_identifier                   = "${var.rds_instance_snapshot_identifier}"

  vpc_security_group_ids                = "${var.rds_instance_vpc_security_group_ids}"
  db_subnet_group_name                  = "${var.rds_instance_db_subnet_group_name}"
  parameter_group_name                  = "${var.rds_instance_parameter_group_name}"
  #option_group_name                     = "${var.rds_instance_option_group_name}"
  option_group_name                     = "${var.rds_instance_option_group_name == "" && var.rds_instance_backup_enabled ? aws_db_option_group.rds_instance_new_option_group.name : var.rds_instance_option_group_name}"

  availability_zone                     = "${var.rds_instance_availability_zone}"
  multi_az                              = "${var.rds_instance_multi_az}"
  iops                                  = "${var.rds_instance_iops}"
  publicly_accessible                   = "${var.rds_instance_publicly_accessible}"
  monitoring_interval                   = "${var.rds_instance_monitoring_interval}"
  monitoring_role_arn                   = "${coalesce(var.rds_instance_monitoring_role_arn, join("",aws_iam_role.enhanced_monitoring.*.arn))}"

  allow_major_version_upgrade           = "${var.rds_instance_allow_major_version_upgrade}"
  auto_minor_version_upgrade            = "${var.rds_instance_auto_minor_version_upgrade}"
  apply_immediately                     = "${var.rds_instance_apply_immediately}"
  maintenance_window                    = "${var.rds_instance_maintenance_window}"
  skip_final_snapshot                   = "${var.rds_instance_skip_final_snapshot}"
  copy_tags_to_snapshot                 = "${var.rds_instance_copy_tags_to_snapshot}"
  final_snapshot_identifier             = "${var.rds_instance_final_snapshot_identifier}"
  max_allocated_storage                 = "${var.rds_instance_max_allocated_storage}"

  performance_insights_enabled          = "${var.rds_instance_performance_insights_enabled}"
  performance_insights_retention_period = "${var.rds_instance_performance_insights_enabled == true ? var.rds_instance_performance_insights_retention_period : 0}"

  backup_retention_period               = "${var.rds_instance_backup_retention_period}"
  backup_window                         = "${var.rds_instance_backup_window}"

  character_set_name                    = "${var.rds_instance_character_set_name}"

  enabled_cloudwatch_logs_exports       = "${var.rds_instance_enabled_cloudwatch_logs_exports}"

  deletion_protection                   = "${var.rds_instance_deletion_protection}"

  tags = "${merge(map("Name", format("%s", var.rds_instance_identifier)), var.rds_instance_tags )}"

  timeouts {
    create = "${lookup(var.rds_instance_timeouts, "create", "")}"
    delete = "${lookup(var.rds_instance_timeouts, "delete", "")}"
    update = "${lookup(var.rds_instance_timeouts, "update", "")}"
  }
}

resource "aws_db_instance" "this_mssql" {
  count = "${var.rds_instance_create && local.is_mssql ? 1 : 0}"

  identifier                            = "${var.rds_instance_identifier}"

  engine                                = "${var.rds_instance_engine}"
  engine_version                        = "${var.rds_instance_engine_version}"
  instance_class                        = "${var.rds_instance_instance_class}"
  allocated_storage                     = "${var.rds_instance_allocated_storage}"
  storage_type                          = "${var.rds_instance_storage_type}"
  storage_encrypted                     = "${var.rds_instance_storage_encrypted}"
  kms_key_id                            = "${var.rds_instance_kms_key_id}"
  license_model                         = "${var.rds_instance_license_model}"

  name                                  = "${var.rds_instance_name}"
  username                              = "${var.rds_instance_username}"
  password                              = "${var.rds_instance_password == "" ? random_string.randommssql.*.result[count.index] : var.rds_instance_password}"
  port                                  = "${var.rds_instance_port}"
  iam_database_authentication_enabled   = "${var.rds_instance_iam_database_authentication_enabled}"

  replicate_source_db                   = "${var.rds_instance_replicate_source_db}"

  snapshot_identifier                   = "${var.rds_instance_snapshot_identifier}"

  vpc_security_group_ids                = "${var.rds_instance_vpc_security_group_ids}"
  db_subnet_group_name                  = "${var.rds_instance_db_subnet_group_name}"
  parameter_group_name                  = "${var.rds_instance_parameter_group_name}"
  option_group_name                     = "${var.rds_instance_option_group_name == "" && var.rds_instance_backup_enabled ? aws_db_option_group.rds_instance_new_option_group.name : var.rds_instance_option_group_name}"

  availability_zone                     = "${var.rds_instance_availability_zone}"
  multi_az                              = "${var.rds_instance_multi_az}"
  iops                                  = "${var.rds_instance_iops}"
  publicly_accessible                   = "${var.rds_instance_publicly_accessible}"
  monitoring_interval                   = "${var.rds_instance_monitoring_interval}"
  monitoring_role_arn                   = "${coalesce(var.rds_instance_monitoring_role_arn, join("",aws_iam_role.enhanced_monitoring.*.arn))}"

  allow_major_version_upgrade           = "${var.rds_instance_allow_major_version_upgrade}"
  auto_minor_version_upgrade            = "${var.rds_instance_auto_minor_version_upgrade}"
  apply_immediately                     = "${var.rds_instance_apply_immediately}"
  maintenance_window                    = "${var.rds_instance_maintenance_window}"
  skip_final_snapshot                   = "${var.rds_instance_skip_final_snapshot}"
  copy_tags_to_snapshot                 = "${var.rds_instance_copy_tags_to_snapshot}"
  final_snapshot_identifier             = "${var.rds_instance_final_snapshot_identifier}"
  max_allocated_storage                 = "${var.rds_instance_max_allocated_storage}"

  performance_insights_enabled          = "${var.rds_instance_performance_insights_enabled}"
  performance_insights_retention_period = "${var.rds_instance_performance_insights_enabled == true ? var.rds_instance_performance_insights_retention_period : 0}"

  backup_retention_period               = "${var.rds_instance_backup_retention_period}"
  backup_window                         = "${var.rds_instance_backup_window}"

  timezone                              = "${var.rds_instance_timezone}"

  enabled_cloudwatch_logs_exports       = "${var.rds_instance_enabled_cloudwatch_logs_exports}"

  deletion_protection                   = "${var.rds_instance_deletion_protection}"

  tags = "${merge(map("Name", format("%s", var.rds_instance_identifier)), var.rds_instance_tags )}"

  timeouts {
    create = "${lookup(var.rds_instance_timeouts, "create", "")}"
    delete = "${lookup(var.rds_instance_timeouts, "delete", "")}"
    update = "${lookup(var.rds_instance_timeouts, "update", "")}"
  }
}
