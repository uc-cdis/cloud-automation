#Automatically generated from a corresponding variables.tf on 2022-07-13 11:27:07.216523

#ID of the AWS account that owns the public AMIs
#TODO Figure out what exactly this is
ami_account_id = "707767160287"

#The name of the environment, and the virtual cloud these VM(s) are to be brought up in
env_vpc_name ="csoc_main"

#The ID of the public subnet for this environment
env_public_subnet_id ="subnet-da2c0a87"

#The name of the aws_key_pair SSH key to attach to VMs
ssh_key_name = "rarya_id_rsa"

#The CIDR block used by this VPC
env_vpc_cidr = "10.128.0.0/20"

#The ID of the VPC this VM will run on
env_vpc_id = "vpc-e2b51d99"

#The EC2 instance type to use for VM(s) spun up from this module. For more information on EC2 instance types, see:
#https://aws.amazon.com/ec2/instance-types/
instance_type = "t2.micro"

