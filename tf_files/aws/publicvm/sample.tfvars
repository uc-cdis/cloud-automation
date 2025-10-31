#Automatically generated from a corresponding variables.tf on 2022-07-12 16:07:24.564137

#The name of the VPC these resources will be spun up in
vpc_name = "vadcprod"

#The EC2 instance type to use for VM(s) spun up from this module. For more information on EC2 instance types, see:
#https://aws.amazon.com/ec2/instance-types/
instance_type = "t3.small"

#Security group for SSH
ssh_in_secgroup = "ssh_eks_vadcprod"

#The name of the security group for egress. This should already exist
egress_secgroup = "out"

#The public subnet located under vpc_name. By default is set to public
subnet_name = "public"

#Volume size of the VM in GB (technically GiB, but what's a few bits among friends?)
volume_size = 500

#List of policy ARNs to attach to the role that will be attached to this VM
policies = []

#The AMI to use for the machine, if nothing is specified, the latest version of Ubuntu available will be used
ami = ""

#The name for the VM, should be unique.
vm_name= ""

