#Automatically generated from a corresponding variables.tf on 2022-07-13 10:48:45.059589

#The CIDR block used by the VPC this deployment will reside on
env_vpc_cidr = "172.24.192.0/20"

#The CIDR block used by the subnet in the VPC where this deployment will reside
squid_proxy_subnet = "172.24.197.0/24"

#The name of the VPC this deployment will live on
env_vpc_name = "raryav1"

#The name of the Squid cluster 
env_squid_name = "commons_squid_auto"

#ID of the AWS account that owns the public AMIs
#TODO Figure out a better description for this
ami_account_id = "099720109477"

#A filter to apply against the names of AMIs when searching. We search, rather than specifying a specific image,
#to ensure that all of the latest security updates are present.
image_name_search_criteria = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"

#The CIDR block of the VPC where you are running the gen3 command
peering_cidr = "10.128.0.0/20"

#A secondary CIDR block, if you require an expanded subnet
secondary_cidr_block= ""

#The path to the bootstrap script to start up Squid instances
bootstrap_path = "cloud-automation/flavors/squid_auto/"

#The name of the bootstrap script
bootstrap_script = "squid_running_on_docker.sh"

#The EC2 instance type to use for VM(s) spun up from this module. For more information on EC2 instance types, see:
#https://aws.amazon.com/ec2/instance-types/
squid_instance_type = "t3.medium"

#Oranization used for tagging and tracking in AWS
organization_name = "Basic Services"

#AWS Cloudwatch Logs Group name where logs will be sent
env_log_group= ""

#The ID of the VPC where the proxy cluster will reside
env_vpc_id= ""

#The name of an AWS SSH key pair to attach to EC2 instances. For more information,
#see https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html
ssh_key_name= ""

#Size of the root volume for each instance, in GB
squid_instance_drive_size = 8

#AZs where the Squid instances will be deployed
squid_availability_zones= ""

#The route table that allows public access
main_public_route= ""

#Public kube route table ID
private_kube_route= ""

#DNS zone for .internal.io
route_53_zone_id= ""

#Beanch to use in the bootstrap script
branch = "master"

#Additional variables to pass along with the bootstrap script
extra_vars = ["squid_image=master"]

#How many Squid instances are desired for the cluster
cluster_desired_capasity = 2

#The maximum number of Squid instances allowed on the cluster
cluster_max_size = 3

#The minimum number of Squid instances allowed on the cluster
cluster_min_size = 1

#Whether or not to provide an expanded network
network_expansion = true

#Whether or not to deploy Squid in a high-availability (i.e., multi-node) configuration
deploy_ha_squid = true

#Used to register with Qualys, which provides security scanning services
activation_id = ""

#Used to register with Qualys, which provides security scanning services
customer_id = ""

#A webhook used to send alarms to a Slack channel
slack_webhook = ""

