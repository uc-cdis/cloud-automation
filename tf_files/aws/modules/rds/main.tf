
resource "aws_db_instance" "rds_instance" {
  allocated_storage           = "${var.rds_instance_volume_size}"
  storage_type                = "${var.rds_instance_storage_type}"
  engine                      = "${var.rds_instance_engine}"
  engine_version              = "${var.rds_instance_engine_version}"
  instance_class              = "${var.rds_instance_class}"
  name                        = "${var.rds_instance_name}"
  username                    = "${var.rds_instance_username}"
  password                    = "${var.rds_instance_password}"
  parameter_group_name        = "${var.rds_instance_parameter_group_name}"
  allow_major_version_upgrade = "${var.rds_instance_allow_major_version_update}"
  apply_immediately           = "${var.rds_instance_apply_immediately}"
  auto_minor_version_upgrade  = "${var.rds_instance_auto_minor_version_upgrade}"
  availability_zone           = "${var.rds_instance_az}"
  backup_retention_period     = "${var.rds_instance_backup_retention_period}"
  backup_window               = "${var.rds_instance_backup_window}"
  db_subnet_group_name        = "${var.rds_instance_db_subnet_group_name}"
  maintenance_window          = "${var.rds_instance_maintenance_window}"
  multi_az                    = "${var.rds_instance_multi_az}"
  option_group_name           = "${var.rds_instance_option_group_name}"
  publicly_accessible         = "${var.rds_instance_publicly_accessible}"
  skip_final_snapshot         = "${var.rds_instance_skip_final_snapshot}"
  storage_encrypted           = "${var.rds_instance_storage_encrypted}"
  vpc_security_group_ids      = "${var.rds_instance_vpc_security_group_ids}"
  final_snapshot_identifier   = "${replace(var.rds_instance_name,"_", "-")}-final-snapshot"
  port                        = "${var.rds_instance_port}"
  license_model               = "${var.rds_instance_license_model}"
  
  tags                        = "${var.rds_instance_tags}"

  lifecycle {
    prevent_destroy = true
  }
}
