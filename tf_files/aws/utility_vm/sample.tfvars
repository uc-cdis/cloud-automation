#Automatically generated from a corresponding variables.tf on 2022-07-13 15:41:28.272806

#ID of the AWS account that owns the public AMIs
#TODO Figure out what this means
ami_account_id = "099720109477"

#Account ID of where the VM would be spun up. By default we use CSOC's.
aws_account_id = "433568766270"

#What AWS region to deploy this VM in
aws_region = "us-east-1"

#The ID of the VPC to deploy this VM in
vpc_id = "vpc-e2b51d99"

#The ID of the subnet to deploy this VM in
vpc_subnet_id = "subnet-6127013c"

#List of CIDRs to overpass the proxy
vpc_cidr_list = ["10.128.0.0/20", "54.0.0.0/8", "52.0.0.0/8"]

#The name of an AWS SSH key pair to attach to EC2 instances. For more information,
#see https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html
ssh_key_name= ""

#The name of the environment this runs in, for tagging purposes
environment = "CSOC"

#The EC2 instance type to use for VM(s) spun up from this module. For more information on EC2 instance types, see:
#https://aws.amazon.com/ec2/instance-types/
instance_type = "t2.micro"

#The EC2 instance type to use for VM(s) spun up from this module. For more information on EC2 instance types, see:
#https://aws.amazon.com/ec2/instance-types/
image_name_search_criteria = "ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-2018*"

extra_vars = ["hostname=stuff","accountid=34534534534"]

#The full name of the directory in which the bootstrap script is located
bootstrap_path = "cloud-automation/flavors/nginx/"

#The name of the bootstrap script
bootstrap_script = "es_revproxy.sh"

#The name given to the VM in AWS
vm_name = "nginx_server"

#The hostname given to the Vm
vm_hostname = "csoc_nginx_server"

#If the VM will be behind a proxy
proxy = true

#The location of a file that has all the keys authorized to access this VM
authorized_keys = "files/authorized_keys/ops_team"

#The name of the organization, used for tracking and tagging in AWS
organization_name = "Basic Service"

#The branch of cloud-automation to use for this VM
branch = "master"

#A policy to allow the user to pull log events
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

#Used for Qualys monitoring
activation_id = ""

#Used for Qualys monitoring
customer_id = ""

