#Automatically generated from a corresponding variables.tf on 2022-07-12 13:47:23.877126

#The VPC this EKS cluster should be spun up
vpc_name= ""

#The name of an AWS SSH key pair to attach to EC2 instances. For more information,
#see https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html
ec2_keyname = "someone@uchicago.edu"

#The EC2 instance type to use for VM(s) spun up from this module. For more information on EC2 instance types, see:
#https://aws.amazon.com/ec2/instance-types/
instance_type = "t3.large"

#The type of instance to use for nodes running jupyter
jupyter_instance_type = "t3.large"

#The type of instance to use for nodes running workflows
workflow_instance_type = "t3.2xlarge"

#This is the CIDR of the network your adminVM is on. Since the commons creates its own VPC, you need to pair them up to allow communication between them later.
peering_cidr = "10.128.0.0/20"

#A CIDR block, if needed to expand available addresses for workflows
secondary_cidr_block = ""

#The ID of the VPC this cluster is to be peered with
peering_vpc_id = "vpc-e2b51d99"

#This is the policy that was created before that allows the cluster to access the users bucket in bionimbus. 
#Usually the same name as the VPC, but not always.
users_policy= ""

#The size of the volumes for the workers, in GB
worker_drive_size = 30

#The EKS version this cluster should run against
eks_version = "1.16"

#Whether you want your workers on a /24 or /23 subnet, /22 is available, but the VPC module should have been deployed 
#using the `network_expansion = true` variable, otherwise wks will fail
workers_subnet_size = 24

#The script used to start up the workers
#https://github.com/uc-cdis/cloud-automation/tree/master/flavors/eks`
bootstrap_script = "bootstrap-with-security-updates.sh"

#The script used to start up Jupyter nodes
#https://github.com/uc-cdis/cloud-automation/tree/master/flavors/eks
jupyter_bootstrap_script = "bootstrap-with-security-updates.sh"

#If your bootstrap script requires another kernel, you could point to it with this variable. Available kernels will be in 
#`gen3-kernels` bucket.
kernel = "N/A"

#The size, in GB, of the drives to be attached to Jupyter workers\
jupyter_worker_drive_size = 30

#A script used to start up a workflow
workflow_bootstrap_script =  "bootstrap.sh"

#The size, in GB, of the drives to be attached to workflow workers
workflow_worker_drive_size = 30

#CIDRs you want to skip the proxy when going out
cidrs_to_route_to_gw = []

#Organization name, for tagging purposes
organization_name = "Basic Services"

#The number of Jupyter workers
jupyter_asg_desired_capacity = 0

#The maximum number of Jupyter workers
jupyter_asg_max_size = 10

#The minimum number of Jupyter workers
jupyter_asg_min_size = 0

#The number of Jupyter workers
workflow_asg_desired_capacity = 0

#The maximum number of Jupyter workers
workflow_asg_max_size = 50

#The minimum number of Jupyter workers
workflow_asg_min_size = 0

#Whether to add a service account to your cluster
iam-serviceaccount = true

#URL for the lambda function to use to check for the proxy
domain_test = "www.google.com"

#Is HA squid deployed?
ha_squid = false

#Deploy workflow nodepool?
deploy_workflow = false

#If migrating from single to ha, set to true, should not disrrupt connectivity
dual_proxy = false

#Should all Jupyter notebooks exist in the same AZ?
single_az_for_jupyter = false

#Thumbprint for the AWS OIDC identity provider
oidc_eks_thumbprint = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]

#The ARN of an SNS topic that will be used to send alerts
sns_topic_arn = "arn:aws:sns:us-east-1:433568766270:planx-csoc-alerts-topic"

#Used for authenticating Qualys software, which is used to perform security scans
activation_id = ""

#Used for authenticating Qualys software, which is used to perform security scans
customer_id = ""

#This controls whether or not we use FIPS enabled AMIs
fips = false

#The key that was used to encrypt the FIPS enabled AMI. This is needed so ASG can decrypt the AMI
fips_ami_kms = "arn:aws:kms:us-east-1:707767160287:key/mrk-697897f040ef45b0aa3cebf38a916f99"

#This is the FIPS enabled AMI in cdistest account
fips_enabled_ami = "ami-074d352c8e753fc93"

#A list of AZs to be used by EKS nodes
availability_zones = ["us-east-1a", "us-east-1c", "us-east-1d"]

