#####
#
# Module to create a new EKS cluster 
#
#####


## First thing we need to create the role that would spin up resources for us 

resource "aws_iam_role" "eks_role" {
  name = "${var.vpc_name}_EKS_role"

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



data "aws_iam_policy_document" "eks_policy_document" {
  statement {
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:UpdateAutoScalingGroup",
      "ec2:AttachVolume",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateRoute",
      "ec2:CreateSecurityGroup",
      "ec2:CreateTags",
      "ec2:CreateVolume",
      "ec2:DeleteRoute",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteVolume",
      "ec2:DescribeInstances",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVolumes",
      "ec2:DescribeVolumesModifications",
      "ec2:DescribeVpcs",
      "ec2:DetachVolume",
      "ec2:ModifyInstanceAttribute",
      "ec2:ModifyVolume",
      "ec2:RevokeSecurityGroupIngress",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
      "elasticloadbalancing:AttachLoadBalancerToSubnets",
      "elasticloadbalancing:ConfigureHealthCheck",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateLoadBalancerListeners",
      "elasticloadbalancing:CreateLoadBalancerPolicy",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteLoadBalancerListeners",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeLoadBalancerPolicies",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DetachLoadBalancerFromSubnets",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:SetLoadBalancerPoliciesForBackendServer",
      "elasticloadbalancing:SetLoadBalancerPoliciesOfListener",
      "kms:DescribeKey"
    ]

    effect    = "Allow"
    resources = ["*"]
  },
  statement {
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:CreateNetworkInterfacePermission",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
      "ec2:ModifyNetworkInterfaceAttribute",
      "iam:ListAttachedRolePolicies"
    ]
    effect    = "Allow"
    resources = ["*"]
  },
  statement {
    actions = [
      "ec2:CreateTags",
      "ec2:DeleteTags"
    ]
    effect    = "Allow"
    resources = ["arn:aws:ec2:*:*:vpc/*","arn:aws:ec2:*:*:subnet/*"]
  }  
}


resource "aws_iam_policy" "eks_access" {
  name        = "${var.vpc_name}_eks_access"
  description = "${var.vpc_name} EKS access"
  policy      = "${data.aws_iam_policy_document.eks_policy_document.json}"
}

#resource "aws_iam_role_policy_attachment" "eks_access_sg" {
#  role       = "${aws_iam_role.eks_role.name}"
#  policy_arn = "${aws_iam_policy.eks_access.arn}"
#}

resource "aws_iam_role_policy_attachment" "eks-policy-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.eks_role.name}"
#  role       = "${aws_iam_role.EKSClusterRole.name}"
}

resource "aws_iam_role_policy_attachment" "eks-policy-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.eks_role.name}"
#  role       = "${aws_iam_role.EKSClusterRole.name}"
}


data "aws_availability_zones" "available" {
  state = "available"
}

####
#* aws_eks_cluster.eks_cluster: error creating EKS Cluster (fauziv1): UnsupportedAvailabilityZoneException: Cannot create cluster 'fauziv1' because us-east-1e, the targeted availability zone, does not currently have sufficient capacity to support the cluster. Retry and choose from these availability zones: us-east-1a, us-east-1c, us-east-1d
####


resource "random_shuffle" "az" {
#  input = ["${data.aws_availability_zones.available.names}"] 
  input = ["us-east-1a", "us-east-1c", "us-east-1d"]
  result_count = 3
  count = 1
}

data "aws_vpcs" "vpcs" {
  tags {
    Name = "${var.vpc_name}"
  }
}

# Assuming that there is only one VPC with the vpc_name
data "aws_vpc" "the_vpc" {
  id = "${element(data.aws_vpcs.vpcs.ids, count.index)}"
}


resource "aws_subnet" "eks_private" {
  count = 3
  vpc_id                  = "${element(data.aws_vpcs.vpcs.ids, count.index)}"
  cidr_block              = "${cidrhost(data.aws_vpc.the_vpc.cidr_block, 256 * ( 6 + count.index) )}/24"
  availability_zone       = "${random_shuffle.az.result[count.index]}"
  #availability_zone       = "${element(random_shuffle.az.result, count.index)}"
  map_public_ip_on_launch = false

  tags {
    Name         = "eks_private"
    Environment  = "${var.vpc_name}"
    Organization = "Basic Service"
  }
}


#resource "aws_subnet" "eks_private_2" {
#  vpc_id                  = "${element(data.aws_vpcs.vpcs.ids, count.index)}"
#  cidr_block              = "${cidrhost(data.aws_vpc.the_vpc.cidr_block, 256 * 8 )}/24"
#  availability_zone       = "${element(random_shuffle.az.result, count.index)}"
#  map_public_ip_on_launch = false
#
#  tags {
#    Name         = "eks_private_2"
#    Environment  = "${var.vpc_name}"
#    Organization = "Basic Service"
#  }
#}


#resource "aws_subnet" "eks_private_3" {
#  vpc_id                  = "${element(data.aws_vpcs.vpcs.ids, count.index)}"
#  cidr_block              = "${cidrhost(data.aws_vpc.the_vpc.cidr_block, 256 * 9 )}/24"
#  availability_zone       = "${element(random_shuffle.az.result, count.index)}"
#  map_public_ip_on_launch = false
#
#  tags {
#    Name         = "eks_private_3"
#    Environment  = "${var.vpc_name}"
#    Organization = "Basic Service"
#  }
#}


resource "aws_security_group" "eks_control_plane_sg" {
  name        = "${var.vpc_name}-control-plane"
  description = "Cluster communication with worker nodes [${var.vpc_name}]"
  vpc_id      = "${data.aws_vpc.the_vpc.id}"

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}





resource "aws_eks_cluster" "eks_cluster" {
  name     = "${var.vpc_name}"
  role_arn = "${aws_iam_role.eks_role.arn}"

  vpc_config {

    subnet_ids  = ["${aws_subnet.eks_private.*.id}"]
    security_group_ids = ["${aws_security_group.eks_control_plane_sg.id}"]
  }

#  depends_on = [
#    "aws_iam_role_policy_attachment.eks_access_sg",
#  ]

  depends_on = [
    "aws_iam_role_policy_attachment.eks-policy-AmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.eks-policy-AmazonEKSServicePolicy",
  ]
}


    #subnet_ids  = ["${aws_subnet.eks_private_1.id}", "${aws_subnet.eks_private_2.id}", "${aws_subnet.eks_private_3.id}"]

