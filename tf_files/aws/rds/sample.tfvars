#Automatically generated from a corresponding variables.tf on 2022-07-12 16:47:21.465202

#Whether to create this resource or not?
rds_instance_create = true

#Allocated storage in gibibytes
rds_instance_allocated_storage = 20

#What type of storage to use for the database. 
#More information can be found here: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Storage.html
rds_instance_storage_type = "gp2"

#The database engine to use. Information on types and pricing can be found here:
#https://aws.amazon.com/rds/pricing/?pg=ln&sec=hs
rds_instance_engine = ""

#The engine version to use. If auto_minor_version_upgrade is enabled, you can provide a prefix of the 
#version such as 5.7 (for 5.7.10) and this attribute will ignore differences in the patch version automatically (e.g. 5.7.17)
rds_instance_engine_version = ""

#The instance type of the RDS instance
#https://aws.amazon.com/rds/instance-types/
rds_instance_instance_class = "db.t2.micro"

#Name for the database to be created
rds_instance_name = ""

#The name of the RDS instance, if omitted, Terraform will assign a random, unique identifier
rds_instance_identifier= ""

#Username to use for the RDS instance
rds_instance_username = ""

#Password to use for the RDS instance
rds_instance_password = ""

#A DB parameter group is a reusable template of values for things like RAM allocation that can be associated with a DB instance.
#For more info, see: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_WorkingWithParamGroups.html
rds_instance_parameter_group_name = ""

#Indicates that major version upgrades are allowed
rds_instance_allow_major_version_upgrade = true

#Specifies whether any database modifications are applied immediately, or during the next maintenance window
rds_instance_apply_immediately = false

#Indicates that minor engine upgrades will be applied automatically to the DB instance during the maintenance window
rds_instance_auto_minor_version_upgrade = true

#The number of days to retain backups for. Must be between 0 and 35
rds_instance_backup_retention_period = 0

#The daily time range (in UTC) during which automated backups are created if they are enabled. Example: '09:46-10:16'. Must not overlap with maintenance_window
rds_instance_backup_window = "03:46-04:16"

#Name of DB subnet group. DB instance will be created in the VPC associated with the DB subnet group
rds_instance_db_subnet_group_name = ""

#The window to perform maintenance in
rds_instance_maintenance_window = "Mon:00:00-Mon:03:00"

#Specifies if the RDS instance is multi-AZ
rds_instance_multi_az = false

#Name of the DB option group to associate
rds_instance_option_group_name = ""

#Bool to control if instance is publicly accessible
rds_instance_publicly_accessible = false

#Determines if a final snapshot will be taken of the database before it is deleted. False means that a backup will be taken,
#and true means that none will be
rds_instance_skip_final_snapshot = false

#Specifies whether the DB instance is encrypted
rds_instance_storage_encrypted = false

#A list of VPC security groups to associate with the instance
#For more information, see: https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html
rds_instance_vpc_security_group_ids = []

#Tags for the instance, used for searching and filtering
rds_instance_tags = {}

#The port on which the DB accepts connections
rds_instance_port = ""

#License model information for this DB instance
rds_instance_license_model = ""

#Specifies whether Performance Insights are enabled
rds_instance_performance_insights_enabled = false

#The amount of time in days to retain Performance Insights data. Either 7 (7 days) or 731 (2 years).
rds_instance_performance_insights_retention_period = 7

#(Optional) Updated Terraform resource management timeouts. Applies to `aws_db_instance` in particular to permit resource management times
rds_instance_timeouts = { create = "40m" update = "80m" delete = "40m" }

#Name of the IAM role which will be created when create_monitoring_role is enabled.
rds_instance_monitoring_role_name = "rds-monitoring-role"

#Specifies the value for Storage Autoscaling
rds_instance_max_allocated_storage = 0

#The Availability Zone of the RDS instance
rds_instance_availability_zone = ""

#The ARN for the IAM role that permits RDS to send enhanced monitoring metrics to CloudWatch Logs. Must be specified if monitoring_interval is non-zero.
rds_instance_monitoring_role_arn = ""

#On delete, copy all Instance tags to the final snapshot (if final_snapshot_identifier is specified)
rds_instance_copy_tags_to_snapshot = false

#The ARN for the KMS encryption key. If creating an encrypted replica, set this to the destination KMS ARN. If storage_encrypted is set to true and kms_key_id is not specified the default KMS key created in your account will be used
rds_instance_kms_key_id = ""

#List of log types to enable for exporting to CloudWatch logs. If omitted, no logs will be exported. Valid values (depending on engine): alert, audit, error, general, listener, slowquery, trace, postgresql (PostgreSQL), upgrade (PostgreSQL).
rds_instance_enabled_cloudwatch_logs_exports = []

#The amount of provisioned IOPS. Setting this implies a storage_type of 'io1'
rds_instance_iops = 0

#The database can't be deleted when this value is set to true.
rds_instance_deletion_protection = false

#Specifies whether or mappings of AWS Identity and Access Management (IAM) accounts to database accounts is enabled
rds_instance_iam_database_authentication_enabled = false

#(Optional) Time zone of the DB instance. timezone is currently only supported by Microsoft SQL Server. The timezone can only be set on creation. See MSSQL User Guide for more information.
rds_instance_timezone = ""

#The interval, in seconds, between points when Enhanced Monitoring metrics are collected for the DB instance. To disable collecting Enhanced Monitoring metrics, specify 0. The default is 0. Valid Values: 0, 1, 5, 10, 15, 30, 60.
rds_instance_monitoring_interval = 0

#Specifies whether or not to create this database from a snapshot. This correlates to the snapshot ID you'd find in the RDS console, e.g: rds:production-2015-06-26-06-05.
rds_instance_snapshot_identifier = ""

#Specifies that this resource is a Replicate database, and to use this value as the source database. This correlates to the identifier of another Amazon RDS Database to replicate.
rds_instance_replicate_source_db = ""

#Create IAM role with a defined name that permits RDS to send enhanced monitoring metrics to CloudWatch Logs.
rds_instance_create_monitoring_role = false

#(Optional) The character set name to use for DB encoding in Oracle instances. This can't be changed. See Oracle Character Sets Supported in Amazon RDS for more information
rds_instance_character_set_name = ""

#To enable backups onto S3
rds_instance_backup_enabled = false

#KMS to enable backups onto S3
rds_instance_backup_kms_key = ""

#The bucket to send bacups to
rds_instance_backup_bucket_name = ""

