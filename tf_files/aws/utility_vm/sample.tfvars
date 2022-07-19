#Automatically generated from a corresponding variables.tf on 2022-07-13 15:41:28.272806

#ID of the AWS account that owns the public AMIs
#TODO Figure out what this means
ami_account_id = "099720109477"

#
#TODO Figure out what this is
aws_account_id = "433568766270"

#What AWS region to deploy this VM in
aws_region = "us-east-1"

#The ID of the VPC to deploy this VM in
vpc_id = "vpc-e2b51d99"

#The ID of the subnet to deploy this VM in
vpc_subnet_id = "subnet-6127013c"

#
#TODO Figure out what this is
vpc_cidr_list = ["10.128.0.0/20", "54.0.0.0/8", "52.0.0.0/8"]

#Name of the aws_key_pair SSH key to attach to VMs
#TODO Figure out what service this correlates to
ssh_key_name= ""

#The name of the environment, for tracking and tagging purposes
#TODO Confirm this is just a tag
environment = "CSOC"

#The EC2 instance type to use for this VM
#TODO Add documentation on EC2 instance types
instance_type = "t2.micro"

#
#TODO Figure out what this is
image_name_search_criteria = "ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-2018*"

#
#TODO Figure out what these extra variables are actually used for
extra_vars = ["hostname=stuff","accountid=34534534534"]

#The full name of the directory in which the bootstrap script is located
bootstrap_path = "cloud-automation/flavors/nginx/"

#The name of the bootstrap script
bootstrap_script = "es_revproxy.sh"

#The name given to the VM in AWS
#TODO Make sure this is accurate
vm_name = "nginx_server"

#The hostname given to the Vm
vm_hostname = "csoc_nginx_server"

#Whether or not to use a proxy for
#TODO Figure out what we would use a proxy for
proxy = true

#The location of a file that has all the keys authorized to access this VM
authorized_keys = "files/authorized_keys/ops_team"

#The name of the organization, used for tracking and tagging in AWS
organization_name = "Basic Service"

#The branch of cloud-automation to use for this VM
branch = "master"

#
#TODO Figure out what exactly this is
user_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": ["*"],
      "Sid": ""
    }
  ]
}
POLICY

#
#TODO Figure out what this is 
activation_id = ""

#F
#TODO Figure out what this is
customer_id = ""

