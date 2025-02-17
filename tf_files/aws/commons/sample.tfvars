#Automatically generated from a corresponding variables.tf on 2022-07-28 12:08:31.473975

#The name of the VPC for this commons
vpc_name = "Commons1"

#The CIDR block to allocate to the VPC for this commons
vpc_cidr_block = "172.24.17.0/20"

#A secondary CIDR block to allocate to the VPC for this commons, in case  of network expansion
secondary_cidr_block = false

#The type(s) of traffic covered by flow logs
vpc_flow_traffic = "ALL"

#The region to bring up this commons in
aws_region = "us-east-1"

#An AWS ARN for the certificate to use on the Load Balancer in front of the commons. Because all access to a commons is through HTTPS, this is required
aws_cert_name = "AWS-CERTIFICATE-NAME"

#
#TODO Figure out how to explain this
csoc_account_id = "433568766270"

#The CIDR of the VPC from which the commands to bring up this commons are being run; this will enable access
peering_cidr = "10.128.0.0/20"

#The size of the fence DB, in GiB
fence_db_size = 10

#The size of the sheepdog DB, in GiB
sheepdog_db_size = 10

#The size of the indexd DB, in GiB
indexd_db_size = 10

#The password for the fence DB
db_password_fence= ""

#The password for the gdcapi DB
db_password_gdcapi = ""

#This indexd guid prefix should come from Trevar/ZAC
indexd_prefix = "dg.XXXX/"

#The password for the peregrine DB
db_password_peregrine= ""

#The password for the sheepdog DB
db_password_sheepdog= ""

#The password for the indexd DB
db_password_indexd= ""

#The URL for the data dictionary schema. It must be in JSON format. For more info, see: https://docs.gen3.org/gen3-resources/operator-guide/create-data-dictionary/
dictionary_url= ""

#A configuration to specify a customization profile for the the commons' front-end
portal_app = "dev"

#If you wish to start fence pre-populated with data, this is the RDS snapshot that fence will start off of
fence_snapshot = ""

#If you wish to start gdcapi pre-populated with data, this is the RDS snapshot that gdcapi will start off of
gdcapi_snapshot = ""

#If you wish to start peregrine pre-populated with data, this is the RDS snapshot that peregrine will start off of
peregrine_snapshot = ""

#If you wish to start sheepdog pre-populated with data, this is the RDS snapshot that it will start off of
sheepdog_snapshot = ""

#If you wish to start indexd pre-populated with data, this is the RDS snapshot that it will start off of
indexd_snapshot = ""

#Instance type to use for fence. For more information on DB instance types, see:
#https://aws.amazon.com/rds/instance-types/
fence_db_instance = "db.t3.small"

#Instance type to use for sheepdog. For more information on DB instance types, see:
#https://aws.amazon.com/rds/instance-types/
sheepdog_db_instance = "db.t3.small"

#Instance type to use for indexd. For more information on DB instance types, see:
#https://aws.amazon.com/rds/instance-types/
indexd_db_instance = "db.t3.small"

#Hostname that the commons will use for access; i.e. the URL that people will use to access the commons over the internet
hostname = "dev.bionimbus.org"

#A list of SSH keys that will be added to compute resources deployed by this module, including Squid proxy instances
kube_ssh_key= ""

#Google client ID for authentication purposes. If you don't want to enable Google sign in, leave blank
google_client_id= ""

#Secret for the above client ID. Set this to blank as well if you do not want Google sign in
google_client_secret= ""

#GDCAPI secret key
gdcapi_secret_key= ""

#Search criteria for squid AMI look up
squid_image_search_criteria = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"

#The ID of the VPC that the commands to bring this commons up are run in, for access purposes
peering_vpc_id = "vpc-e2b51d99"

#The name of the NLB service endpoint for Squid
squid-nlb-endpointservice-name = "com.amazonaws.vpce.us-east-1.vpce-svc-0ce2261f708539011"

#A webhook used to send alerts in a Slack channel https://api.slack.com/messaging/webhooks
slack_webhook = ""

#A webhook used to send alerts in a secondary Slack channel https://api.slack.com/messaging/webhooks
secondary_slack_webhook = ""

#Threshold for database storage utilization. Represents a percentage, if this limit is reached, the Slack webhooks are used to send an alert
alarm_threshold = "85"

#The name of the organization, for tagging the resources for easier tracking
organization_name = "Basic Service"

#NOT CURRENTLY IN USE 
mailgun_smtp_host = "smtp.mailgun.org"

#NOT CURRENTLY IN USE
mailgun_api_url = "https://api.mailgun.net/v3/"

#Whether or not fence should be deployed in a highly-available configuraiton
fence_ha = false

#Whether or not sheepdog should be deployed in a highly-available configuration
sheepdog_ha = false

#Whether or not indexd should be deployed in a highly-available configuration
indexd_ha = false

#A maintenance window for fence
fence_maintenance_window = "SAT:09:00-SAT:09:59" 

#A maintenance window for sheepdog
sheepdog_maintenance_window = "SAT:10:00-SAT:10:59" 

#A maintenance window for indexd
indexd_maintenance_window = "SAT:11:00-SAT:11:59" 

#How many snapshots should be kept for fence
fence_backup_retention_period = "4" 

#How many snapshots should be kept for sheepdog
sheepdog_backup_retention_period = "4" 

#How many snapshots should be kept for indexd
indexd_backup_retention_period = "4" 

#A backup window for fence
fence_backup_window = "06:00-06:59" 

#A backup window for sheepdog
sheepdog_backup_window = "07:00-07:59" 

#A backup window for indexd
indexd_backup_window = "08:00-08:59"

#The version of the fence engine to run (by default postgres)
fence_engine_version = "13.3" 

#The version of the sheepdog engine to run
sheepdog_engine_version = "13.3"

#The version of the indexd engine to run
indexd_engine_version = "13.3" 

#Whether or not to enable automatic upgrades of minor version for fence
fence_auto_minor_version_upgrade = "true"

#Whether or not to enable automatic upgrades of minor versions for indexd
indexd_auto_minor_version_upgrade = "true"

#Whether or not to enable automatic upgrades of minor versions for sheepdog
sheepdog_auto_minor_version_upgrade = "true"

#Bucket name where to pull users.yaml for permissions
users_bucket_name = "cdis-gen3-users"

#Name of fence database. Not the same as instance identifier
fence_database_name = "fence"

#Name of sheepdog database. Not the same as instance identifier
sheepdog_database_name = "gdcapi"

#Name of indexd database. Not the same as instance identifier
indexd_database_name = "indexd"

#Username for fence DB
fence_db_username = "fence_user"

#Username for sheepdog DB
sheepdog_db_username = "sheepdog"

#Username for indexd DB
indexd_db_username = "indexd_user"

#Whether or not fence can automatically upgrade major versions
fence_allow_major_version_upgrade = "true"

#Whether or not sheepdog can automatically upgrade major versions
sheepdog_allow_major_version_upgrade = "true"

#Whether or not indexd can automatically upgrade major versions
indexd_allow_major_version_upgrade = "true"

#Instance type for HA squid
ha-squid_instance_type = "t3.medium"

#Volume size for HA squid instances
ha-squid_instance_drive_size = 8

#Bootstrapt script for ha-squid instances
ha-squid_bootstrap_script = "squid_running_on_docker.sh"

#additional variables to pass along with the bootstrapscript
ha-squid_extra_vars = ["squid_image=master"]

#For testing purposes, when something else than the master
branch = "master"

#When fence bot has to access another bucket that wasn't created by the VPC module
fence-bot_bucket_access_arns = []

#Should you want to deploy HA-squid
deploy_ha_squid = false

#If ha squid is enabled and you want to set your own capasity
ha-squid_cluster_desired_capasity = 2

#If ha squid is enabled and you want to set your own min size
ha-squid_cluster_min_size = 1

#If ha squid is enabled and you want to set your own max size
ha-squid_cluster_max_size = 3

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

#Instance type for the single proxy instance
single_squid_instance_type = "t2.micro"

#Let k8s workers be on a /22 subnet per AZ
network_expansion = false

#Whether or not the storage for the RDS instances should be encrypted
rds_instance_storage_encrypted = true

#Maximum allocated storage for autosacaling
fence_max_allocated_storage = 0

#Maximum allocated storage for autosacaling
sheepdog_max_allocated_storage = 0

#Maximum allocated storage for autosacaling
indexd_max_allocated_storage = 0

#Used to authenticate with Qualys, which is used for security scanning. Optional
activation_id = ""

#Used to authenticate with Qualys as well. Also optional
customer_id = ""

#Whether or not to set up the commons in accordance with FIPS, a federal information standard
fips = false

