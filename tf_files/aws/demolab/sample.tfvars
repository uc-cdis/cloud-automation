#Automatically generated from a corresponding variables.tf on 2022-07-12 13:08:48.948730

#The name of the VPC this demo lab will be located on
vpc_name= ""

#The EC2 instance type to use for VM(s) spun up from this module. For more information on EC2 instance types, see:
#https://aws.amazon.com/ec2/instance-types/
instance_type = "t3.small"

#The number of instances in the demo lab
instance_count = 5

#The name of an AWS SSH key pair to attach to EC2 instances. For more information,
#see https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html
ssh_public_key= ""

