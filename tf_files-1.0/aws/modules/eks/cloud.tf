#####
#
# Module to create a new EKS cluster for an existing commons
#
#####

locals{
  # if AZs are explicitly defined as a variable, use those. Otherwise use all the AZs of the current region
  # NOTE: the syntax should improve with Terraform 12
  azs              = var.availability_zones != 0 ? var.availability_zones : data.aws_availability_zones.available.names
  secondary_azs    = var.secondary_availability_zones != 0 ? var.secondary_availability_zones : data.aws_availability_zones.available.names
  ami              = var.fips ? var.fips_enabled_ami : data.aws_ami.eks_worker.id
  eks_priv_subnets = var.secondary_cidr_block != "" ? aws_subnet.eks_secondary_subnet.*.id : aws_subnet.eks_private.*.id
  vpc_id           = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.the_vpc.id
}

module "jupyter_pool" {
  count                         = var.deploy_jupyter ? 1 : 0
  source                        = "../eks-nodepool/"
  ec2_keyname                   = var.ec2_keyname
  users_policy                  = var.users_policy
  nodepool                      = "jupyter"
  vpc_name                      = var.vpc_name
  csoc_cidr                     = var.peering_cidr
  eks_cluster_endpoint          = aws_eks_cluster.eks_cluster.endpoint
  eks_cluster_ca                = aws_eks_cluster.eks_cluster.certificate_authority.0.data
  eks_private_subnets           = aws_subnet.eks_private.*.id
  control_plane_sg              = aws_security_group.eks_control_plane_sg.id
  default_nodepool_sg           = aws_security_group.eks_nodes_sg.id
  eks_version                   = var.eks_version
  nodepool_instance_type        = var.jupyter_instance_type
  kernel                        = var.kernel
  bootstrap_script              = var.jupyter_bootstrap_script
  nodepool_worker_drive_size    = var.jupyter_worker_drive_size
  organization_name             = var.organization_name
  nodepool_asg_desired_capacity = var.jupyter_asg_desired_capacity
  nodepool_asg_max_size         = var.jupyter_asg_max_size
  nodepool_asg_min_size         = var.jupyter_asg_min_size
  activation_id                 = var.activation_id
  customer_id                   = var.customer_id
  vpc_id                        = local.vpc_id
}

module "workflow_pool" {
  count                         = var.deploy_workflow ? 1 : 0
  source                        = "../eks-nodepool/"
  ec2_keyname                   = var.ec2_keyname
  users_policy                  = var.users_policy
  nodepool                      = "workflow"
  vpc_name                      = var.vpc_name
  csoc_cidr                     = var.peering_cidr
  eks_cluster_endpoint          = aws_eks_cluster.eks_cluster.endpoint
  eks_cluster_ca                = aws_eks_cluster.eks_cluster.certificate_authority.0.data
  eks_private_subnets           = local.eks_priv_subnets
  control_plane_sg              = aws_security_group.eks_control_plane_sg.id
  default_nodepool_sg           = aws_security_group.eks_nodes_sg.id
  eks_version                   = var.eks_version
  nodepool_instance_type        = var.workflow_instance_type
  kernel                        = var.kernel
  bootstrap_script              = var.workflow_bootstrap_script
  nodepool_worker_drive_size    = var.workflow_worker_drive_size
  organization_name             = var.organization_name
  nodepool_asg_desired_capacity = var.workflow_asg_desired_capacity
  nodepool_asg_max_size         = var.workflow_asg_max_size
  nodepool_asg_min_size         = var.workflow_asg_min_size
  activation_id                 = var.activation_id
  customer_id                   = var.customer_id
  vpc_id                        = local.vpc_id
}

## First thing we need to create is the role that would spin up resources for us

resource "aws_iam_role" "eks_control_plane_role" {
  name               = "${var.vpc_name}_EKS_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# Attach policies for said role
resource "aws_iam_role_policy_attachment" "eks-policy-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_control_plane_role.name
}

resource "aws_iam_role_policy_attachment" "eks-policy-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_control_plane_role.name
}

# This one must have been created when we deployed the VPC resources
resource "aws_iam_role_policy_attachment" "bucket_write" {
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/bucket_writer_logs-${var.vpc_name}-gen3"
  role       = aws_iam_role.eks_control_plane_role.name
}

resource "random_shuffle" "az" {
  count = 1
  input = local.azs
  result_count = length(local.azs)
}

resource "random_shuffle" "secondary_az" {
  count = 1
  input = local.secondary_azs
  result_count = length(local.secondary_azs)
}

# The subnet where our cluster will live in
resource "aws_subnet" "eks_private" {
  count                   = random_shuffle.az[0].result_count
  vpc_id                  = local.vpc_id
  cidr_block              = var.workers_subnet_size == 22 ? cidrsubnet(data.aws_vpc.the_vpc.cidr_block, 2 , ( 1 + count.index )) : var.workers_subnet_size == 23 ? cidrsubnet(data.aws_vpc.the_vpc.cidr_block, 3 , ( 2 + count.index )) : cidrsubnet(data.aws_vpc.the_vpc.cidr_block, 4 , ( 7 + count.index )) 
  availability_zone       = random_shuffle.az[0].result[count.index]
  map_public_ip_on_launch = false

  lifecycle {
    # allow user to change tags interactively - ex - new kube-aws cluster
    ignore_changes = [tags, availability_zone]
  }  

  tags = tomap({
     "Name": "eks_private_${count.index}",
     "Environment": var.vpc_name,
     "Organization": var.organization_name,
     "kubernetes.io/cluster/${var.vpc_name}": "owned",
     "kubernetes.io/role/internal-elb": "1"})
}

# The subnet for secondary CIDR block utilization
resource "aws_subnet" "eks_secondary_subnet" {
  count                   = var.secondary_cidr_block != "" ? 4 : 0
  vpc_id                  = local.vpc_id
  cidr_block              = cidrsubnet(var.secondary_cidr_block, 2 , count.index)
  availability_zone       = random_shuffle.secondary_az[0].result[count.index]
  map_public_ip_on_launch = false

  lifecycle {
    # allow user to change tags interactively - ex - new kube-aws cluster
    ignore_changes = [tags, availability_zone]
  }  

  tags = tomap({
     "Name": "eks_secondary_cidr_subnet_${count.index}",
     "Environment": var.vpc_name,
     "Organization": var.organization_name,
     "kubernetes.io/cluster/${var.vpc_name}": "owned",
     "kubernetes.io/role/internal-elb": "1"
    })
}


# for the ELB to talk to the worker nodes
resource "aws_subnet" "eks_public" {
  count                   = random_shuffle.az[0].result_count
  vpc_id                  = local.vpc_id
  cidr_block              = var.workers_subnet_size == 22 ? cidrsubnet(data.aws_vpc.the_vpc.cidr_block, 5 , ( 4 + count.index )) : cidrsubnet(data.aws_vpc.the_vpc.cidr_block, 4 , ( 10 + count.index ))
  map_public_ip_on_launch = true
  availability_zone       = random_shuffle.az[0].result[count.index]

  lifecycle {
    # allow user to change tags interactively - ex - new kube-aws cluster
    ignore_changes = [tags, availability_zone]
  }  

  tags = tomap({
     "Name": "eks_public_${count.index}",
     "Environment": "${var.vpc_name}",
     "Organization": "${var.organization_name}",
     "kubernetes.io/cluster/${var.vpc_name}": "shared",
     "kubernetes.io/role/elb": "1",
     "KubernetesCluster": "${var.vpc_name}",
    })
}


resource "aws_route_table" "eks_private" {
  vpc_id = local.vpc_id

  lifecycle {
    #ignore_changes = ["*"]
  }  

  tags = {
    Name         = "eks_private"
    Environment  = var.vpc_name
    Organization = var.organization_name
  }
}


resource "aws_route" "for_peering" {
  route_table_id            = aws_route_table.eks_private.id
  destination_cidr_block    = var.peering_cidr
  vpc_peering_connection_id = data.aws_vpc_peering_connection.pc.id
}


resource "aws_route" "skip_proxy" {
  count                  = length(var.cidrs_to_route_to_gw)
  route_table_id         = aws_route_table.eks_private.id
  destination_cidr_block = element(var.cidrs_to_route_to_gw,count.index)
  nat_gateway_id         = data.aws_nat_gateway.the_gateway.id
  depends_on             = [aws_route_table.eks_private]
}

resource "aws_route" "public_access" {
  count                  = var.ha_squid ? var.dual_proxy ? 1 : 0 : 1
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = aws_route_table.eks_private.id
  network_interface_id   = data.aws_instances.squid_proxy[count.index].ids[0]
}

resource "aws_route_table_association" "private_kube" {
  count          = random_shuffle.az[0].result_count
  subnet_id      = aws_subnet.eks_private.*.id[count.index]
  route_table_id = aws_route_table.eks_private.id
  depends_on     = [aws_subnet.eks_private]
}

resource "aws_route_table_association" "secondary_subnet_kube" {
  count          = var.secondary_cidr_block != "" ? random_shuffle.secondary_az[0].result_count : 0
  subnet_id      = aws_subnet.eks_secondary_subnet.*.id[count.index]
  route_table_id = aws_route_table.eks_private.id
  depends_on     = [aws_subnet.eks_secondary_subnet]
}


resource "aws_security_group" "eks_control_plane_sg" {
  name        = "${var.vpc_name}-control-plane"
  description = "Cluster communication with worker nodes [${var.vpc_name}]"
  vpc_id      = local.vpc_id

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  
  tags = {
    Name         = "${var.vpc_name}-control-plane-sg"
    Environment  = var.vpc_name
    Organization = var.organization_name
  }
}




resource "aws_route_table_association" "public_kube" {
  count          = random_shuffle.az[0].result_count
  subnet_id      = aws_subnet.eks_public.*.id[count.index]
  route_table_id = data.aws_route_table.public_kube.id

  lifecycle {
    # allow user to change tags interactively - ex - new kube-aws cluster
    #ignore_changes = ["id", "subnet_id"]
  }
}


# The actual EKS cluster

resource "aws_eks_cluster" "eks_cluster" {
  name     = var.vpc_name
  role_arn = aws_iam_role.eks_control_plane_role.arn
  version  = var.eks_version

  vpc_config {
    subnet_ids              = flatten([aws_subnet.eks_private[*].id])
    security_group_ids      = [aws_security_group.eks_control_plane_sg.id]
    endpoint_private_access = "true"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks-policy-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks-policy-AmazonEKSServicePolicy,
    aws_subnet.eks_private,
  ]
  
  tags = {
    Environment  = var.vpc_name
    Organization = var.organization_name
  }
}



###############################################
# Worker nodes


## Role

resource "aws_iam_role" "eks_node_role" {
  name               = "eks_${var.vpc_name}_workers_role"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY

  tags = {
    Environment  = var.vpc_name
    Organization = var.organization_name
  }
}


## Policies

resource "aws_iam_policy" "cwl_access_policy" {
    name        = "${var.vpc_name}_EKS_workers_access_to_cloudwatchlogs"
    description = "In order to avoid the creation of users and keys, we are using roles and policies."
    policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "logs:DescribeLogGroups",
            "Resource": "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group::log-stream:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:DescribeLogStreams"
            ],
            "Resource": "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${var.vpc_name}:log-stream:*"
        }
    ]
}
EOF
}

# This policy will allow the autoscaler deployment to add or terminate instance into the group
# https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md
resource "aws_iam_policy" "asg_access" {
    name        = "${var.vpc_name}_EKS_workers_autoscaling_access"
    description = "Allow the deployment cluster-autoscaler to add or terminate instances accordingly"
    policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeTags",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup",
                "autoscaling:DescribeLaunchConfigurations"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "csoc_alert_sns_access" {
  count  = var.sns_topic_arn != "" ? 1 : 0
  name   = "${var.vpc_name}_CSOC_alert_SNS_topic_acess"
  policy = data.aws_iam_policy_document.planx-csoc-alerts-topic_access[count.index].json
  role   = aws_iam_role.eks_node_role.id
}

resource "aws_iam_role_policy_attachment" "eks-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs_access" {
  policy_arn = aws_iam_policy.cwl_access_policy.arn
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "asg_access" {
  policy_arn = aws_iam_policy.asg_access.arn
  role       = aws_iam_role.eks_node_role.name
}

# This one must have been created when we deployed the VPC resources
resource "aws_iam_role_policy_attachment" "bucket_read" {
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/bucket_reader_cdis-gen3-users_${var.users_policy}"
  role       = aws_iam_role.eks_node_role.name
}

# Amazon SSM Policy 
resource "aws_iam_role_policy_attachment" "eks-policy-AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_instance_profile" "eks_node_instance_profile" {
  name = "${var.vpc_name}_EKS_workers"
  role = aws_iam_role.eks_node_role.name
}


## Worker Node Security Group
## This security group controls networking access to the Kubernetes worker nodes.


resource "aws_security_group" "eks_nodes_sg" {
  name        =  "${var.vpc_name}_EKS_workers_sg"
  description = "Security group for all nodes in the EKS cluster [${var.vpc_name}] "
  vpc_id      = local.vpc_id

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = tomap({
     "Name": "${var.vpc_name}-nodes-sg",
     "kubernetes.io/cluster/${var.vpc_name}": "owned",
  })
}



# Worker Node Access to EKS Master Cluster
# Now that we have a way to know where traffic from the worker nodes is coming from,
# we can allow the worker nodes networking access to the EKS master cluster.

# Nodes talk to Control plane
resource "aws_security_group_rule" "https_nodes_to_plane" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_control_plane_sg.id
  source_security_group_id = aws_security_group.eks_nodes_sg.id
  depends_on               = [aws_security_group.eks_nodes_sg, aws_security_group.eks_control_plane_sg]
  description              = "from the workers to the control plane"
}

# Control plane to the workers
resource "aws_security_group_rule" "communication_plane_to_nodes" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 65534
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes_sg.id
  source_security_group_id = aws_security_group.eks_control_plane_sg.id
  depends_on               = [aws_security_group.eks_nodes_sg, aws_security_group.eks_control_plane_sg]
  description              = "from the control plane to the nodes"
}

# Let's allow nodes talk to each other
resource "aws_security_group_rule" "nodes_internode_communications" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  description       = "allow nodes to communicate with each other"
  security_group_id = aws_security_group.eks_nodes_sg.id
  self              = true
}

# Let's allow the two polls talk to each other
resource "aws_security_group_rule" "nodes_interpool_communications" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  description              = "allow jupyter nodes to talk to the default"
  security_group_id        = aws_security_group.eks_nodes_sg.id
  source_security_group_id = module.jupyter_pool[0].nodepool_sg
}

# Let's allow the two polls talk to each other
resource "aws_security_group_rule" "workflow_nodes_interpool_communications" {
  count                    = var.deploy_workflow ? 1 : 0
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  description              = "allow workflow nodes to talk to the default"
  security_group_id        = aws_security_group.eks_nodes_sg.id
  source_security_group_id = module.workflow_pool[0].nodepool_sg
}


## Worker Node AutoScaling Group
# Now we have everything in place to create and manage EC2 instances that will serve as our worker nodes
# in the Kubernetes cluster. This setup utilizes an EC2 AutoScaling Group (ASG) rather than manually working with
# EC2 instances. This offers flexibility to scale up and down the worker nodes on demand when used in conjunction
# with AutoScaling policies (not implemented here).


# EKS currently documents this required userdata for EKS worker nodes to
# properly configure Kubernetes applications on the EC2 instance.
# We utilize a Terraform local here to simplify Base64 encoding this
# information into the AutoScaling Launch Configuration.
# More information: https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/amazon-eks-nodegroup.yaml

# See template.tf for more information about the bootstrap script


resource "aws_launch_configuration" "eks_launch_configuration" {
  count                       = var.enable_on_demand_instances ? 1 : 0
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.eks_node_instance_profile.name
  image_id                    = local.ami
  instance_type               = var.instance_type
  name_prefix                 = "eks-${var.vpc_name}"
  security_groups             = [aws_security_group.eks_nodes_sg.id, aws_security_group.ssh.id]
  user_data_base64            = base64encode(templatefile("${path.module}/../../../../flavors/eks/${var.bootstrap_script}", {eks_ca = aws_eks_cluster.eks_cluster.certificate_authority.0.data, eks_endpoint = aws_eks_cluster.eks_cluster.endpoint, eks_region = data.aws_region.current.name, vpc_name = var.vpc_name, ssh_keys = templatefile("${path.module}/../../../../files/authorized_keys/ops_team", {}), nodepool = "default", activation_id = var.activation_id, customer_id = var.customer_id}))
  key_name                    = var.ec2_keyname

  root_block_device {
    volume_size = var.worker_drive_size
  }

  lifecycle {
    create_before_destroy = true
    #ignore_changes  = ["user_data_base64"]
  }
}

resource "aws_launch_template" "eks_launch_template" {
  count                                = var.enable_spot_instances ? 1 : 0
  name                                 = "eks-${var.vpc_name}-launch-configuration"
  instance_type                        = var.instance_type
  image_id                             = local.ami
  key_name                             = var.ec2_keyname
  #vpc_security_group_ids              = ["${aws_security_group.eks_nodes_sg.id}", "${aws_security_group.ssh.id}"]
  user_data                            = base64encode(templatefile("${path.module}/../../../../flavors/eks/${var.bootstrap_script}", {eks_ca = aws_eks_cluster.eks_cluster.certificate_authority.0.data, eks_endpoint = aws_eks_cluster.eks_cluster.endpoint, eks_region = data.aws_region.current.name, vpc_name = var.vpc_name, ssh_keys = templatefile("${path.module}/../../../../files/authorized_keys/ops_team", {}), nodepool = "default", activation_id = var.activation_id, customer_id = var.customer_id}))
  instance_initiated_shutdown_behavior = "terminate"
  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = var.worker_drive_size
    }
  }
  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.eks_nodes_sg.id, aws_security_group.ssh.id]
  }
  iam_instance_profile {
    name = aws_iam_instance_profile.eks_node_instance_profile.name
  }
}

# Create a new iam service linked role that we can grant access to KMS keys in other accounts
# Needed if we need to bring up custom AMI's that have been encrypted using a kms key
resource "aws_iam_service_linked_role" "autoscaling" {
  aws_service_name = "autoscaling.amazonaws.com"
  custom_suffix = var.vpc_name
  lifecycle {
    ignore_changes  = ["custom_suffix"]
  }
}

# Remember to grant access to the account in the KMS key policy too
resource "aws_kms_grant" "kms" {
  count             = var.fips ? 1 : 0
  name              = "kms-cmk-eks"
  key_id            = var.fips_ami_kms
  grantee_principal = aws_iam_service_linked_role.autoscaling.arn
  operations        = ["Encrypt", "Decrypt", "ReEncryptFrom", "ReEncryptTo", "GenerateDataKey", "GenerateDataKeyWithoutPlaintext", "DescribeKey", "CreateGrant"]
}

resource "aws_autoscaling_group" "eks_autoscaling_group" {
  count                   = var.enable_on_demand_instances ? 1 : 0
  service_linked_role_arn = aws_iam_service_linked_role.autoscaling.arn
  desired_capacity        = 2
  launch_configuration    = aws_launch_configuration.eks_launch_configuration[0].id
  max_size                = 10
  min_size                = 2
  name                    = "eks-worker-node-${var.vpc_name}"
  vpc_zone_identifier     = flatten([aws_subnet.eks_private.*.id])

  tag {
    key                 = "Environment"
    value               = var.vpc_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "eks-${var.vpc_name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.vpc_name}"
    value               = "owned"
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = ""
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/cluster-type/eks"
    value               = ""
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/nodepool/default"
    value               = ""
    propagate_at_launch = true
  }

# Avoid unnecessary changes for existing commons running on EKS
  lifecycle {
    ignore_changes = [desired_capacity, max_size, min_size]
  }
}

resource "aws_autoscaling_group" "eks_mixed_autoscaling_group" {
  count                   = var.enable_spot_instances ? 1 : 0
  capacity_rebalance      = true
  service_linked_role_arn = aws_iam_service_linked_role.autoscaling.arn
  desired_capacity        = 2
  max_size                = 10
  min_size                = 2
  name                    = "eks-mixed-worker-node-${var.vpc_name}"
  vpc_zone_identifier     = [aws_subnet.eks_private.*.id]

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = var.minimum_on_demand_nodes
      spot_allocation_strategy                 = "lowest-price"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.eks_launch_template[0].id
        version = "$Latest"
      }
    }
  }

  tag {
    key                 = "Environment"
    value               = "${var.vpc_name}"
    propagate_at_launch = true
  }
  tag {
    key                 = "Name"
    value               = "eks-${var.vpc_name}"
    propagate_at_launch = true
  }
  tag {
    key                 = "kubernetes.io/cluster/${var.vpc_name}"
    value               = "owned"
    propagate_at_launch = true
  }
  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = ""
    propagate_at_launch = true
  }
  tag {
    key                 = "k8s.io/cluster-type/eks"
    value               = ""
    propagate_at_launch = true
  }
  tag {
    key                 = "k8s.io/nodepool/default"
    value               = ""
    propagate_at_launch = true
  }
# Avoid unnecessary changes for existing commons running on EKS
  lifecycle {
    ignore_changes = [desired_capacity,max_size,min_size]
  }

  depends_on     = [aws_launch_template.eks_launch_template]
}


# Let's allow ssh just in case
resource "aws_security_group" "ssh" {
  name        = "ssh_eks_${var.vpc_name}"
  description = "security group that only enables ssh"
  vpc_id      = local.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment  = var.vpc_name
    Organization = var.organization_name
    Name         = "ssh_eks_${var.vpc_name}"
  }
}


# NOTE: At this point, your Kubernetes cluster will have running masters and worker nodes, however, the worker nodes will
# not be able to join the Kubernetes cluster quite yet. The next section has the required Kubernetes configuration to
# enable the worker nodes to join the cluster.

# Required Kubernetes Configuration to Join Worker Nodes
# The EKS service does not provide a cluster-level API parameter or resource to automatically configure the underlying
# Kubernetes cluster to allow worker nodes to join the cluster via AWS IAM role authentication.

# To output an IAM Role authentication ConfigMap from your Terraform configuration:

locals {
  config-map-aws-auth  = var.deploy_workflow ? local.cm1 : local.cm2
  cm1 = <<CONFIGMAPAWSAUTH
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_iam_role.eks_node_role.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: ${module.jupyter_pool[0].nodepool_role}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: ${var.deploy_workflow ? module.workflow_pool[0].nodepool_role : ""}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
CONFIGMAPAWSAUTH
  cm2 = <<CONFIGMAPAWSAUTH2
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_iam_role.eks_node_role.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: ${module.jupyter_pool[0].nodepool_role}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
CONFIGMAPAWSAUTH2
}



#--------------------------------------------------------------
# We need to have the kubeconfigfile somewhere, even if it is temporaty so we can execute stuff agains the freshly create EKS cluster
# Legacy stuff ...
# We want to move away from generating output files, and
# instead just publish output variables
#
resource "null_resource" "config_setup" {
   triggers = {
    kubeconfig_change = templatefile("${path.module}/kubeconfig.tpl", {vpc_name = var.vpc_name, eks_name = aws_eks_cluster.eks_cluster.id, eks_endpoint = aws_eks_cluster.eks_cluster.endpoint, eks_cert = aws_eks_cluster.eks_cluster.certificate_authority.0.data,})
    configmap_change  = local.config-map-aws-auth
  }

  provisioner "local-exec" {
    command = "mkdir -p ${var.vpc_name}_output_EKS; echo '${templatefile("${path.module}/kubeconfig.tpl", {vpc_name = var.vpc_name, eks_name = aws_eks_cluster.eks_cluster.id, eks_endpoint = aws_eks_cluster.eks_cluster.endpoint, eks_cert = aws_eks_cluster.eks_cluster.certificate_authority.0.data,})}' >${var.vpc_name}_output_EKS/kubeconfig"
  }

  provisioner "local-exec" {
    command = "echo \"${local.config-map-aws-auth}\" > ${var.vpc_name}_output_EKS/aws-auth-cm.yaml"
  }

  provisioner "local-exec" {
    command = "echo \"${templatefile("${path.module}/init_cluster.sh", { vpc_name = var.vpc_name, kubeconfig_path = "${var.vpc_name}_output_EKS/kubeconfig", auth_configmap = "${var.vpc_name}_output_EKS/aws-auth-cm.yaml"})}\" > ${var.vpc_name}_output_EKS/init_cluster.sh"
  }

  provisioner "local-exec" {
    command = "bash ${var.vpc_name}_output_EKS/init_cluster.sh"
  }

  depends_on = [aws_autoscaling_group.eks_autoscaling_group]
}

#--------------------------------------------------------------
# let's work towards EKS IAM-ServiceAccount integration

resource "aws_iam_openid_connect_provider" "identity_provider" {
  count              = "${var.iam-serviceaccount ? var.eks_version == "1.12" ? 0 : 1 : 0}"
  url             = "${aws_eks_cluster.eks_cluster.identity.0.oidc.0.issuer}"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = "${var.oidc_eks_thumbprint}"
  depends_on      = [aws_eks_cluster.eks_cluster]
}
