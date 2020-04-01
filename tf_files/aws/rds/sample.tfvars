
# Mandatory variables
rds_instance_allocated_storage            = 20
rds_instance_engine                       = "MySQL,postgres,oracle,aurora,SQL,MariaDB"
rds_instance_engine_version               = "version for your engine, basically depends on the variable above"
rds_instance_username                     = "usern ame for access"
#rds_instance_password                     = "password for access"
rds_instance_port                         = "1433"
rds_instance_identifier                   = "planx-tests-db"
#rds_instance_db_subnet_group_name         = "subnet group name"
#rds_instance_vpc_security_group_ids       = ["sg-XXXXXXXXXX"]


# Optional variables, uncomment and change values accordingly

#rds_instance_name                                  = "what are you naming the db"
#rds_instance_allow_major_version_upgrade           = true
#rds_instance_apply_immediately                     = false
#rds_instance_auto_minor_version_upgrade            = true
#rds_instance_availability_zone                     = ""
#rds_instance_backup_retention_period               = 0
#rds_instance_backup_window                         = "03:46-04:16"
#rds_instance_character_set_name                    = ""
#rds_instance_copy_tags_to_snapshot                 = false
#rds_instance_create                                = true
#rds_instance_deletion_protection                   = false
#rds_instance_enabled_cloudwatch_logs_exports       = []
#rds_instance_iam_database_authentication_enabled   = false
#rds_instance_instance_class                        = "db.t3.micro"
#rds_instance_iops                                  = 0
#rds_instance_kms_key_id                            = ""
#rds_instance_license_model                         = false
#rds_instance_maintenance_window                    = "Mon:00:00-Mon:03:00"
#rds_instance_max_allocated_storage                 = 0
#rds_instance_monitoring_interval                   = 0
#rds_instance_monitoring_role_arn                   = ""
#rds_instance_monitoring_role_name                  = "rds-monitoring-role"
#rds_instance_multi_az                              = false
#rds_instance_option_group_name                     = ""
#rds_instance_parameter_group_name                  = ""
#rds_instance_performance_insights_enabled          = false
#rds_instance_performance_insights_retention_period = 7
#rds_instance_publicly_accessible                   = false
#rds_instance_replicate_source_db                   = ""
#rds_instance_skip_final_snapshot                   = false
#rds_instance_snapshot_identifier                   = ""
#rds_instance_storage_encrypted                     = false
#rds_instance_storage_type                          = "gp2"
#rds_instance_tags                                  = {"something"="stuff", "Something-else"="more-stuff"}
#rds_instance_timeouts                              = {create = "40m", update = "80m", delete = "40m"}
#rds_instance_timezone                              = ""
#rds_instance_final_snapshot_identifier             = ""

# backups 
#rds_instance_backup_enabled                         = false
#rds_instance_backup_kms_key                         = ""
#rds_instance_backup_bucket_name                     = ""

