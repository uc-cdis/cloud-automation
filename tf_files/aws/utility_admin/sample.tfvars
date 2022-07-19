#Automatically generated from a corresponding variables.tf on 2022-07-13 14:39:54.673037

#ID of the AWS account that owns the public AMIs
#TODO Figure out what this actually means
ami_account_id = "099720109477"

#
#TODO Figure out what this actually is
aws_account_id = "433568766270"

#The AWS region to spin up this resource in
aws_region = "us-east-1"

#The ID of the VPC to spin up this resource in
vpc_id = "vpc-e2b51d99"

#The ID of the subnet to spin up this resource in
vpc_subnet_id = "subnet-6127013c"

#
#TODO Figure out what this actually is
vpc_cidr_list = ["10.128.0.0/20", "54.0.0.0/8", "52.0.0.0/8"]

#The name of the aws_key_pair SSH key to attach to VMs
#TODO Figure out what service this correlates to
ssh_key_name= ""

#The name of the environment this runs in
#TODO Figure out a better description for this
environment = "CSOC"

#The EC2 instance type to run this VM on
#TODO Add documentation on EC2 instance types
instance_type = "t3.micro"

#
#TODO Figure out what exactly this is
image_name_search_criteria = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"

#Extra variables that can be applied
#TODO Figure out what these can be applied to, they may just be tags
extra_vars = ["hostname=stuff","accountid=34534534534"]

#The directory in which the bootstrap script is located
bootstrap_path = "cloud-automation/flavors/nginx/"

#The name of the bootstrap script
bootstrap_script = "es_revproxy.sh"

#The name to be given to this VM
#TODO Figure out if this its AWS name or something else
vm_name = "nginx_server"

#The hostname to be given to this VM
vm_hostname = "csoc_nginx_server"

#Whether or not to use a proxy for
#TODO Figure out what we would be using a proxy for
proxy = true

#A file containing keys authorized to access this VM
authorized_keys = "files/authorized_keys/ops_team"

#The name of the organization, used for tagging and tracking in AWS
organization_name = "Basic Service"

#The branch of the repo to use
#TODO Confirm that the repo that this is using is cloud-automation
branch = "master"

