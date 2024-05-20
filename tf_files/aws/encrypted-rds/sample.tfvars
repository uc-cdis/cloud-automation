#Automatically generated from a corresponding variables.tf on 2022-07-12 15:15:28.628361

#The name of the VPC this RDS instance will be attached to
vpc_name = "vpcName"

#The CIDR block used in the VPC
vpc_cidr_block = "172.24.17.0/20"

#The region to spin up all the resources in
aws_region = "us-east-1"

#
#TODO Look this one up and get it right
csoc_account_id = "433568766270"

#The CIDR for the peering VPC
peering_cidr = "10.128.0.0/20"

#The size, in GB, of the Fence DB
fence_db_size = 10

#The size, in GB, of the Sheepdog DB
sheepdog_db_size = 10

#The size, in GB, of the Indexd DB
indexd_db_size = 10

#The password for the Fence DB
db_password_fence= ""

#The password for the GDCAPI DB
db_password_gdcapi = ""

#The password for the Peregrine DB
db_password_peregrine= ""

#The password for the Sheepdog DB
db_password_sheepdog= ""

#The password for the Indexd DB
db_password_indexd= ""

#A snapshot of an RDS databse, used to populate this DB with data
fence_snapshot = ""

#A snapshot of an RDS databse, used to populate this DB with data
gdcapi_snapshot = ""

#A snapshot of an RDS databse, used to populate this DB with data
peregrine_snapshot = ""

#A snapshot of an RDS databse, used to populate this DB with data
sheepdog_snapshot = ""

#A snapshot of an RDS databse, used to populate this DB with data
indexd_snapshot = ""

#The instance type to run the Fence DB on
#https://aws.amazon.com/rds/instance-types/
fence_db_instance = "db.t3.small"

#The instance type to run the Sheepdog DB on
#https://aws.amazon.com/rds/instance-types/
sheepdog_db_instance = "db.t3.small"

#The instance type to run the Indexd DB on
#https://aws.amazon.com/rds/instance-types/
indexd_db_instance = "db.t3.small"

#The ID of the peered VPC
peering_vpc_id = "vpc-e2b51d99"

#A webhook used to send alerts in a Slack channel
#https://api.slack.com/messaging/webhooks
slack_webhook = ""

#A webhook used to send alerts in a secondary Slack channel
#https://api.slack.com/messaging/webhooks
secondary_slack_webhook = ""

#Threshold for database storage utilization. This is a number that represents a percentage of storage used. 
#Once this alarm is triggered, the webhook is used to send a notification via Slack
alarm_threshold = "85"

#Organization used for tagging & tracking purposes
organization_name = "Basic Service"

#Boolean that represents if Fence should be deployed in a high-availability configuration
fence_ha = false

#Boolean that represents if Sheepdog should be deployed in a high-availability configuration
sheepdog_ha = false

#Boolean that represents if Indexd should be deployed in a high-availabiity configuration
indexd_ha = false

#The maintenance window for Fence
#Format is ddd:hh24:mi-ddd:hh24:mi". Eg: "Mon:00:00-Mon:03:00"
fence_maintenance_window = "SAT:09:00-SAT:09:59"

#Boolean that represents if the RDS instance's storage should be encrypted
rds_instance_storage_encrypted = true

#The maintenance window for Sheepdog
#Format is ddd:hh24:mi-ddd:hh24:mi". Eg: "Mon:00:00-Mon:03:00"
sheepdog_maintenance_window = "SAT:10:00-SAT:10:59"

#The maintenance window for Indexd
#Format is ddd:hh24:mi-ddd:hh24:mi". Eg: "Mon:00:00-Mon:03:00"
indexd_maintenance_window = "SAT:11:00-SAT:11:59"

#How many snapshots of the database should be kept at a time
fence_backup_retention_period = "4"

#How many snapshots of the database should be kept at a time
sheepdog_backup_retention_period = "4"

#How many snapshots of the database should be kept at a time
indexd_backup_retention_period = "4"

#The time range when Fence can be backed up
#Format is ddd:hh24:mi-ddd:hh24:mi". Eg: "Mon:00:00-Mon:03:00"
fence_backup_window = "06:00-06:59"

#The time range when Sheepdog can be backed up
#Format is ddd:hh24:mi-ddd:hh24:mi". Eg: "Mon:00:00-Mon:03:00"
sheepdog_backup_window = "07:00-07:59"

#The time range when Indexd can be backed up
#Format is ddd:hh24:mi-ddd:hh24:mi". Eg: "Mon:00:00-Mon:03:00"
indexd_backup_window = "08:00-08:59"

#The version of the database software used to run the database
fence_engine_version = "13.3"

#The version of the database software used to run the database
sheepdog_engine_version = "13.3"

#The version of the database software used to run the database
indexd_engine_version = "13.3"

#Whether the database can automatically update minor versions
fence_auto_minor_version_upgrade = "true"

#Whether the database can automatically update minor versions
indexd_auto_minor_version_upgrade = "true"

#Whether the database can automatically update minor versions
sheepdog_auto_minor_version_upgrade = "true"

#Name of the Fence database. Not the same as the instance identifier
fence_database_name = "fence"

#Name of the Sheepdog database. Not the same as the instance identifier
sheepdog_database_name = "gdcapi"

#Name of the Indexd database. Not the same as the isntance identifier
indexd_database_name = "indexd"

#The username for the Fence database
fence_db_username = "fence_user"

#The username for the Sheepdog database
sheepdog_db_username = "sheepdog"

#the username for the Indexd database
indexd_db_username = "indexd_user"

#Boolean that controls if the database is allowed to automatically upgrade major versions
fence_allow_major_version_upgrade = "true"

#Boolean that controls if the database is allowed to automatically upgrade major versions
sheepdog_allow_major_version_upgrade = "true"

#Boolean that controls if the database is allowed to automatically upgrade major versions
indexd_allow_major_version_upgrade = "true"

#Whether or not to deploy the database instance
deploy_sheepdog_db = true

#Whether or not to deploy the database instance
deploy_fence_db = true

#Whether or not to deploy the database instance
deploy_indexd_db = true

#Engine to deploy the db instance
sheepdog_engine = "postgres"

#Engine to deploy the db instance
fence_engine = "postgres"

#Engine to deploy the db instance
indexd_engine = "postgres"

#The security group to add the DB instances to
security_group_local_id = "securityGroupId"

#The subnet group for databases that this DB should be spun up in
aws_db_subnet_group_name = "subnetName"

#Maximum allocated storage for autoscaling
fence_max_allocated_storage = 0

#Maximum allocated storage for autoscaling
sheepdog_max_allocated_storage = 0

#Maximum allocated storage for autoscaling
indexd_max_allocated_storage = 0

