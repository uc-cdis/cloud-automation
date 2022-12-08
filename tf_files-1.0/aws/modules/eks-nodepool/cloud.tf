locals {
  vpc_id = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.the_vpc.id
}

resource "aws_iam_role" "eks_control_plane_role" {
  name               = "${var.vpc_name}_EKS_${var.nodepool}_role"
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

resource "aws_iam_role_policy_attachment" "eks-policy-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_control_plane_role.name
}

resource "aws_iam_role_policy_attachment" "eks-policy-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_control_plane_role.name
}

resource "aws_iam_role_policy_attachment" "bucket_write" {
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/bucket_writer_logs-${var.vpc_name}-gen3"
  role       = aws_iam_role.eks_control_plane_role.name
}

# Amazon SSM Policy 
resource "aws_iam_role_policy_attachment" "eks-policy-AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks_control_plane_role.name
}



###############################################
# Worker nodes


## Role
resource "aws_iam_role" "eks_node_role" {
  name               = "eks_${var.vpc_name}_nodepool_${var.nodepool}_role"
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
}


## Policies

resource "aws_iam_policy" "cwl_access_policy" {
    name        = "${var.vpc_name}_EKS_nodepool_${var.nodepool}_access_to_cloudwatchlogs"
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

resource "aws_iam_policy" "access_to_kernels" {
    name        = "${var.vpc_name}_EKS_nodepool_${var.nodepool}_kernel_access"
    description = "To access custom Kernels"
    policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "s3:List*",
                "s3:Get*"
            ],
            "Resource": [
                "arn:aws:s3:::gen3-kernels/*",
                "arn:aws:s3:::gen3-kernels",
                "arn:aws:s3:::qualys-agentpackage",
                "arn:aws:s3:::qualys-agentpackage/*"
            ]
        }
    ]
}
EOF
}

# This policy will allow the autoscaler deployment to add or terminate instance in the group
# https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md
resource "aws_iam_policy" "asg_access" {
    name        = "${var.vpc_name}_EKS_nodepool_${var.nodepool}_autoscaling_access"
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

resource "aws_iam_role_policy_attachment" "kernel_access" {
  policy_arn = aws_iam_policy.access_to_kernels.arn
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_instance_profile" "eks_node_instance_profile" {
  name = "${var.vpc_name}_EKS_nodepool_${var.nodepool}"
  role = aws_iam_role.eks_node_role.name
}

## Worker Node Security Group
## This security group controls networking access to the Kubernetes worker nodes.

resource "aws_security_group" "eks_nodes_sg" {
  name        = "${var.vpc_name}_EKS_nodepool_${var.nodepool}_sg"
  description = "Security group for all nodes in pool ${var.nodepool} in the EKS cluster [${var.vpc_name}] "
  vpc_id      = local.vpc_id

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = tomap({
     "Name": "${var.vpc_name}-nodes-sg-${var.nodepool}",
     "kubernetes.io/cluster/${var.vpc_name}": "owned"
  })
}



# Worker Node Access to EKS Master Cluster
# Now that we have a way to know where traffic from the worker nodes is coming from,
# we can allow the worker nodes networking access to the EKS master cluster.

resource "aws_security_group_rule" "https_nodes_to_plane" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = var.control_plane_sg
  source_security_group_id = aws_security_group.eks_nodes_sg.id
  depends_on               = [aws_security_group.eks_nodes_sg]
}


resource "aws_security_group_rule" "communication_plane_to_nodes" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 65534
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes_sg.id
  source_security_group_id = var.control_plane_sg
  depends_on               = [aws_security_group.eks_nodes_sg]
}

resource "aws_security_group_rule" "nodes_internode_communications" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  description       = "allow nodes to communicate with each other"
  security_group_id = aws_security_group.eks_nodes_sg.id
  self              = true
}

resource "aws_security_group_rule" "nodes_interpool_communications" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  description              = "allow default nodes to communicate with each other"
  security_group_id        = aws_security_group.eks_nodes_sg.id
  source_security_group_id = var.default_nodepool_sg
}

## Worker Node AutoScaling Group
# Now we have everything in place to create and manage EC2 instances that will serve as our worker nodes
# in the Kubernetes cluster. This setup utilizes an EC2 AutoScaling Group (ASG) rather than manually working with
# EC2 instances. This offers flexibility to scale up and down the worker nodes on demand when used in conjunction
# with AutoScaling policies (not implemented here).


resource "aws_launch_configuration" "eks_launch_configuration" {
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.eks_node_instance_profile.name
  image_id                    = data.aws_ami.eks_worker.id
  instance_type               = var.nodepool_instance_type
  name_prefix                 = "eks-${var.vpc_name}-nodepool-${var.nodepool}"
  security_groups             = [aws_security_group.eks_nodes_sg.id, aws_security_group.ssh.id]
  user_data_base64            = base64encode(templatefile("${path.module}/../../../../flavors/eks/${var.bootstrap_script}",{eks_ca = var.eks_cluster_ca, eks_endpoint = var.eks_cluster_endpoint, eks_region = data.aws_region.current.name, vpc_name = var.vpc_name, ssh_keys = templatefile("${path.module}/../../../../files/authorized_keys/ops_team",{}), nodepool = var.nodepool, lifecycle_type = "ONDEMAND", kernel = var.kernel, activation_id = var.activation_id, customer_id = var.customer_id}))
  key_name                    = var.ec2_keyname

  root_block_device {
    volume_size = var.nodepool_worker_drive_size
  }

  lifecycle {
    create_before_destroy = true
    #ignore_changes  = [user_data_base64]
  }
}

resource "aws_autoscaling_group" "eks_autoscaling_group" {
  desired_capacity      = var.nodepool_asg_desired_capacity
  protect_from_scale_in = var.scale_in_protection
  launch_configuration  = aws_launch_configuration.eks_launch_configuration.id
  max_size              = var.nodepool_asg_max_size
  min_size              = var.nodepool_asg_min_size
  name                  = "eks-${var.nodepool}worker-node-${var.vpc_name}"
  vpc_zone_identifier   = flatten([var.eks_private_subnets])

  tag {
    key                 = "Environment"
    value               = var.vpc_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "eks-${var.vpc_name}-${var.nodepool}"
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
    key                 = "k8s.io/nodepool/${var.nodepool}"
    value               = ""
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/node-template/label/role"
    value               = "${var.nodepool}"
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/node-template/taint/role"
    value               = "${var.nodepool}:NoSchedule"
    propagate_at_launch = true
  }

# Avoid unnecessary changes for existing commons running on EKS
  lifecycle {
    ignore_changes = [desired_capacity]
    #ignore_changes = [desired_capacity,max_size,min_size]
  }
}


# Let's allow ssh just in case
resource "aws_security_group" "ssh" {
  name        = "ssh_eks_${var.vpc_name}-nodepool-${var.nodepool}"
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
    Name         = "ssh_eks_${var.vpc_name}-nodepool-${var.nodepool}"
  }
}
