# TL;DR

Deploy an RDS instance according to variables passed along

## 1. QuickStart

```
gen3 workon <profile> <instance-name>__rds
```

Ex.
```
$ gen3 workon cdistest newdb__rds
```

## 2. Table of content

- [1. QuickStart](#1-quickstart)
- [2. Table of Contents](#2-table-of-contents)
- [3. Overview](#3-overview)
- [4. Variables](#4-variables)
  - [4.1 Required Variables](#41-required-variables)
  - [4.2 Optional Variables](#42-optional-variables)
- [5. Considerations](#5-considerations)



## 3. Overview

Once you workon the workspace, you may want to edit the config.tfvars accordingly.

There are mandatory variables, and there are a few other optionals that are set by default in the variables.tf file, but you could change them accordingly.


## 4. Variables

### 4.1 Required Variables

| Name | Description | Type | Default |
|------|-------------|:----:|:-----:|
| rds_instance_allocated\_storage | The allocated storage in gigabytes | string | n/a |
| rds_instance_engine | The database engine to use | string | n/a |
| rds_instance_engine\_version | The engine version to use | string | n/a |
| rds_instance_username | Username for the master DB user | string | n/a |
| rds_instance_port | The port on which the DB accepts connections | string | n/a |
| rds_instance_identifier | The name of the RDS instance, if omitted, Terraform will assign a random, unique identifier | string | n/a |




### 4.2 Optional Variables



| Name | Description | Type | Default |
|------|-------------|:----:|:-----:|
| rds_instance_allow\_major\_version\_upgrade | Indicates that major version upgrades are allowed. Changing this parameter does not result in an outage and the change is asynchronously applied as soon as possible | bool | `"false"` |
| rds_instance_apply\_immediately | Specifies whether any database modifications are applied immediately, or during the next maintenance window | bool | `"false"` |
| rds_instance_auto\_minor\_version\_upgrade | Indicates that minor engine upgrades will be applied automatically to the DB instance during the maintenance window | bool | `"true"` |
| rds_instance_availability\_zone | The Availability Zone of the RDS instance | string | `""` |
| rds_instance_backup\_retention\_period | The days to retain backups for | number | `"1"` |
| rds_instance_backup\_window | The daily time range (in UTC) during which automated backups are created if they are enabled. Example: '09:46-10:16'. Must not overlap with maintenance_window | string | "03:46-04:16"" |
| rds_instance_character\_set\_name | (Optional) The character set name to use for DB encoding in Oracle instances. This can't be changed. See Oracle Character Sets Supported in Amazon RDS for more information | string | `""` |
| rds_instance_copy\_tags\_to\_snapshot | On delete, copy all Instance tags to the final snapshot (if final_snapshot_identifier is specified) | bool | `"false"` |
| rds_instance_create | Whether to create this resource or not? | bool | `"true"` |
| rds_instance_create\_monitoring\_role | Create IAM role with a defined name that permits RDS to send enhanced monitoring metrics to CloudWatch Logs. | bool | `"false"` |
| rds_instance_db\_subnet\_group\_name | Name of DB subnet group. DB instance will be created in the VPC associated with the DB subnet group. If unspecified, will be created in the default VPC | string | `""` |
| rds_instance_deletion\_protection | The database can't be deleted when this value is set to true. | bool | `"false"` |
| rds_instance_enabled\_cloudwatch\_logs\_exports | List of log types to enable for exporting to CloudWatch logs. If omitted, no logs will be exported. Valid values (depending on engine): alert, audit, error, general, listener, slowquery, trace, postgresql (PostgreSQL), upgrade (PostgreSQL). | list(string) | `[]` |
| rds_instance_final\_snapshot\_identifier | The name of your final DB snapshot when this DB instance is deleted. | string | `"null"` |
| rds_instance_iam\_database\_authentication\_enabled | Specifies whether or mappings of AWS Identity and Access Management (IAM) accounts to database accounts is enabled | bool | `"false"` |
| rds_instance_instance\_class | The instance type of the RDS instance | string | db.t2.micro |
| rds_instance_iops | The amount of provisioned IOPS. Setting this implies a storage_type of 'io1' | number | `"0"` |
| rds_instance_kms\_key\_id | The ARN for the KMS encryption key. If creating an encrypted replica, set this to the destination KMS ARN. If storage_encrypted is set to true and kms_key_id is not specified the default KMS key created in your account will be used | string | `""` |
| rds_instance_license\_model | License model information for this DB instance. Optional, but required for some DB engines, i.e. Oracle SE1 | string | `""` |
| rds_instance_maintenance\_window | The window to perform maintenance in. Syntax: 'ddd:hh24:mi-ddd:hh24:mi'. Eg: 'Mon:00:00-Mon:03:00' | string | "Mon:00:00-Mon:03:00" |
| rds_instance_max\_allocated\_storage | Specifies the value for Storage Autoscaling | number | `"0"` |
| rds_instance_monitoring\_interval | The interval, in seconds, between points when Enhanced Monitoring metrics are collected for the DB instance. To disable collecting Enhanced Monitoring metrics, specify 0. The default is 0. Valid Values: 0, 1, 5, 10, 15, 30, 60. | number | `"0"` |
| rds_instance_monitoring\_role\_arn | The ARN for the IAM role that permits RDS to send enhanced monitoring metrics to CloudWatch Logs. Must be specified if monitoring_interval is non-zero. | string | `""` |
| rds_instance_monitoring\_role\_name | Name of the IAM role which will be created when create_monitoring_role is enabled. | string | `"rds-monitoring-role"` |
| rds_instance_multi\_az | Specifies if the RDS instance is multi-AZ | bool | `"false"` |
| rds_instance_name | The DB name to create. If omitted, no database is created initially | string | `""` |
| rds_instance_option\_group\_name | Name of the DB option group to associate. | string | `""` |
| rds_instance_parameter\_group\_name | Name of the DB parameter group to associate | string | `""` |
| rds_instance_password | Password for the master DB user. Note that this may show up in logs, and it will be stored in the state file, if not provided, a random 16 char long password will be used | string | "" |
| rds_instance_performance\_insights\_enabled | Specifies whether Performance Insights are enabled | bool | `"false"` |
| rds_instance_performance\_insights\_retention\_period | The amount of time in days to retain Performance Insights data. Either 7 (7 days) or 731 (2 years). | number | `"7"` |
| rds_instance_publicly\_accessible | Bool to control if instance is publicly accessible | bool | `"false"` |
| rds_instance_replicate\_source\_db | Specifies that this resource is a Replicate database, and to use this value as the source database. This correlates to the identifier of another Amazon RDS Database to replicate. | string | `""` |
| rds_instance_skip\_final\_snapshot | Determines whether a final DB snapshot is created before the DB instance is deleted. If true is specified, no DBSnapshot is created. If false is specified, a DB snapshot is created before the DB instance is deleted, using the value from final_snapshot_identifier | bool | `"true"` |
| rds_instance_snapshot\_identifier | Specifies whether or not to create this database from a snapshot. This correlates to the snapshot ID you'd find in the RDS console, e.g: rds:production-2015-06-26-06-05. | string | `""` |
| rds_instance_storage\_encrypted | Specifies whether the DB instance is encrypted | bool | `"false"` |
| rds_instance_storage\_type | One of 'standard' (magnetic), 'gp2' (general purpose SSD), or 'io1' (provisioned IOPS SSD). The default is 'io1' if iops is specified, 'standard' if not. Note that this behaviour is different from the AWS web console, where the default is 'gp2'. | string | `"gp2"` |
| rds_instance_tags | A mapping of tags to assign to all resources | map(string) | `{}` |
| rds_instance_timeouts | (Optional) Updated Terraform resource management timeouts. Applies to `aws_db_instance` in particular to permit resource management times | map(string) | `{ "create": "40m", "delete": "40m", "update": "80m" }` |
| rds_instance_timezone | (Optional) Time zone of the DB instance. timezone is currently only supported by Microsoft SQL Server. The timezone can only be set on creation. See MSSQL User Guide for more information. | string | `""` |
| rds_instance_vpc\_security\_group\_ids | List of VPC security groups to associate | list(string) | `[]` |
| rds_instance_backup_enabled | To enable backups onto S3 | boolean | `false` |
| rds_instance_backup_kms_key | KMS key to enable backups onto S3 | string | `""` |
| rds_instance_backup_bucket_name | The bucket to send bacups to | string | `""` | 

## 5. Considerations

* Setting the variables properly would warrantee the proper run of the module, cenrtain engines have certain version, and certain variables only work for certain engines.
  For more information about RDS, and possible values, please go to https://docs.aws.amazon.com/cli/latest/reference/rds/create-db-instance.html


## 6. Outputs

| Name | Description |
|------|-------------|
| rds_instance_\_instance\_address | The address of the RDS instance |
| rds_instance_\_instance\_arn | The ARN of the RDS instance |
| rds_instance_\_instance\_availability\_zone | The availability zone of the RDS instance |
| rds_instance_\_instance\_endpoint | The connection endpoint |
| rds_instance_\_instance\_hosted\_zone\_id | The canonical hosted zone ID of the DB instance (to be used in a Route 53 Alias record) |
| rds_instance_\_instance\_id | The RDS instance ID |
| rds_instance_\_instance\_name | The database name |
| rds_instance_\_instance\_port | The database port |
| rds_instance_\_instance\_resource\_id | The RDS Resource ID of this instance |
| rds_instance_\_instance\_status | The RDS instance status |
| rds_instance_\_instance\_username | The master username for the database |
| rds_instance_\_instance\_password | The master password for the database |
