vpc_name = "THE_VPC_NAME - default is: vadcprod"

instance_type = "default is: t3.small"

ssh_in_secgroup = "should already exist - default is: ssh_eks_vadcprod"

egress_secgroup = "should already exist - default is: out"

subnet_name = "public subnet under vpc_name - default is: public"

volume_size = "for the vm - default is 500"

policies    = ["list of policies ARNs to attach to the role that will be attached to this VM"
