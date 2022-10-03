#Automatically generated from a corresponding variables.tf on 2022-07-12 12:32:59.347063

#The name to use for the Qualys VM. This field is mandatory. This VM will be used
#to run Qualys, a security application.
vm_name = "qualys_scanner_prod"

#The ID of the VPC to spin up this VM
vpc_id = "vpc-e2b51d99"

#The CIDR block for the VPC subnet the VM will be
env_vpc_subnet = "10.128.3.0/24"

#Route table the VM will be associated with
qualys_pub_subnet_routetable_id = "rtb-7ee06301"

#The name of an AWS SSH key pair to attach to EC2 instances. For more information,
#see https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html
ssh_key_name = "rarya_id_rsa"

#The code used to register with Qualys. This field is mandatory
user_perscode ="20079167409920"

#A filter to apply against the names of AMIs when searching. We search, rather than specifying a specific image,
#to ensure that all of the latest security updates are present.
image_name_search_criteria = "a04e299c-fb8e-4ee2-9a75-94b76cf20fb2"

#A filter to apply against the descriptions of AMIs when searching. We search, rather than specifying a specific image,
#to ensure that all of the latest security updates are present.
image_desc_search_criteria = ""

#Account id of the AMI owner, which is used to further filter the search for an AMI
ami_account_id = "679593333241"

#Organization for tagging puposes
organization = "PlanX"

#Environment for tagging purposes
environment = "CSOC"

#The EC2 instance type to use for VM(s) spun up from this module. For more information on EC2 instance types, see:
#https://aws.amazon.com/ec2/instance-types/
instance_type = "t3.medium"

