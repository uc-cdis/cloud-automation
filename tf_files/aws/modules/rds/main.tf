

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

  role       = "${aws_iam_role.enhanced_monitoring.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
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
  password                              = "${var.rds_instance_password}"
  port                                  = "${var.rds_instance_port}"
  iam_database_authentication_enabled   = "${var.rds_instance_iam_database_authentication_enabled}"

  replicate_source_db                   = "${var.rds_instance_replicate_source_db}"

  snapshot_identifier                   = "${var.rds_instance_snapshot_identifier}"

  vpc_security_group_ids                = "${var.rds_instance_vpc_security_group_ids}"
  db_subnet_group_name                  = "${var.rds_instance_db_subnet_group_name}"
  parameter_group_name                  = "${var.rds_instance_parameter_group_name}"
  option_group_name                     = "${var.rds_instance_option_group_name}"

  availability_zone                     = "${var.rds_instance_availability_zone}"
  multi_az                              = "${var.rds_instance_multi_az}"
  iops                                  = "${var.rds_instance_iops}"
  publicly_accessible                   = "${var.rds_instance_publicly_accessible}"
  monitoring_interval                   = "${var.rds_instance_monitoring_interval}"
  #monitoring_role_arn                   = "${coalesce(var.rds_instance_monitoring_role_arn, aws_iam_role.enhanced_monitoring.*.arn, "")}"
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
  password                              = "${var.rds_instance_password}"
  port                                  = "${var.rds_instance_port}"
  iam_database_authentication_enabled   = "${var.rds_instance_iam_database_authentication_enabled}"

  replicate_source_db                   = "${var.rds_instance_replicate_source_db}"

  snapshot_identifier                   = "${var.rds_instance_snapshot_identifier}"

  vpc_security_group_ids                = "${var.rds_instance_vpc_security_group_ids}"
  db_subnet_group_name                  = "${var.rds_instance_db_subnet_group_name}"
  parameter_group_name                  = "${var.rds_instance_parameter_group_name}"
  option_group_name                     = "${var.rds_instance_option_group_name}"

  availability_zone                     = "${var.rds_instance_availability_zone}"
  multi_az                              = "${var.rds_instance_multi_az}"
  iops                                  = "${var.rds_instance_iops}"
  publicly_accessible                   = "${var.rds_instance_publicly_accessible}"
  monitoring_interval                   = "${var.rds_instance_monitoring_interval}"
  #monitoring_role_arn                   = "${coalesce(var.rds_instance_monitoring_role_arn, length(aws_iam_role.enhanced_monitoring.*.arn) > 0 ? aws_iam_role.enhanced_monitoring.arn : "", "")}"
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
