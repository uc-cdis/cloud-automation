#####
#
# Module to create a new EKS cluster for an existing commons
#
# fauzi@uchicago.edu
#
#####


## First thing we need to create the role that would spin up resources for us 

resource "aws_iam_role" "eks_control_plane_role" {
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

# Attach policies for said role
resource "aws_iam_role_policy_attachment" "eks-policy-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.eks_control_plane_role.name}"
}

resource "aws_iam_role_policy_attachment" "eks-policy-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.eks_control_plane_role.name}"
}



# Let's get the availability zones for the region we are working on
data "aws_availability_zones" "available" {
  state = "available"
}

####
# * aws_eks_cluster.eks_cluster: error creating EKS Cluster (fauziv1): UnsupportedAvailabilityZoneException: Cannot create cluster 'fauziv1' because us-east-1e, the targeted availability zone, does not currently have sufficient capacity to support the cluster. Retry and choose from these availability zones: us-east-1a, us-east-1c, us-east-1d
####
resource "random_shuffle" "az" {
#  input = ["${data.aws_availability_zones.available.names}"] 
  input = ["us-east-1a", "us-east-1c", "us-east-1d"]
  result_count = 3
  count = 1
}


# Let's grab the vpc we already created in the VPC module.

data "aws_vpcs" "vpcs" {
  tags {
    Name = "${var.vpc_name}"
  }
}

# Assuming that there is only one VPC with the vpc_name
data "aws_vpc" "the_vpc" {
  id = "${element(data.aws_vpcs.vpcs.ids, count.index)}"
}

# The subnet where our cluster will live in 
resource "aws_subnet" "eks_private" {
  count = 3
#  vpc_id                  = "${element(data.aws_vpcs.vpcs.ids, count.index)}"
  vpc_id                  = "${data.aws_vpc.the_vpc.id}"
  #cidr_block              = "${cidrhost(data.aws_vpc.the_vpc.cidr_block, 256 * ( 6 + count.index) )}/24"
  cidr_block              = "${cidrsubnet(data.aws_vpc.the_vpc.cidr_block, 4 , ( 6 + count.index ))}"
  availability_zone       = "${random_shuffle.az.result[count.index]}"
#  availability_zone       = "${element(random_shuffle.az.result, count.index)}"
  map_public_ip_on_launch = false

  tags {
    Name         = "eks_private_${count.index}"
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

# Since we need to access the internet through the proxy, let find it

data "aws_instances" "squid_proxy" {
  instance_tags {
    Name = "${var.vpc_name} HTTP Proxy"
  }
}


# Also we want to access AWS stuff directly though an existing 
# nat gateway instead than going through the proxy
data "aws_nat_gateway" "the_gateway" {
  vpc_id = "${data.aws_vpc.the_vpc.id}"
}

# Also let's allow comminication through the peering

data "aws_vpc_peering_connection" "pc" {
  vpc_id          = "${data.aws_vpc.the_vpc.id}"
}

resource "aws_route_table" "eks_private" {
  vpc_id = "${data.aws_vpc.the_vpc.id}"

  route {
    cidr_block  = "0.0.0.0/0"
    instance_id = "${data.aws_instances.squid_proxy.ids[0]}"
  }

  # We want to be able to talk to aws freely, therefore we are allowing 
  # certain stuff overpass the proxy
  route {
    # logs.us-east-1.amazonaws.com
    cidr_block     = "52.0.0.0/8"
    nat_gateway_id = "${data.aws_nat_gateway.the_gateway.id}"
  }
  route {
    # logs.us-east-1.amazonaws.com as well, these guys are not static, therefore whitelist the whole list
    cidr_block     = "54.0.0.0/8"
    nat_gateway_id = "${data.aws_nat_gateway.the_gateway.id}"
  }
  route {
    # .us-east-1.eks.amazonaws.com 
    cidr_block     = "34.192.0.0/10"
    nat_gateway_id = "${data.aws_nat_gateway.the_gateway.id}"
  }

  route {
    #from the commons vpc to the csoc vpc via the peering connection
    cidr_block                = "${var.csoc_cidr}"
    vpc_peering_connection_id = "${data.aws_vpc_peering_connection.pc.id}"
  }

  tags {
    Name         = "eks_private"
    Environment  = "${var.vpc_name}"
    Organization = "Basic Service"
  }
}


# Apparently we cannot iterate over the resource, therefore I am querying them after creation
data "aws_subnet_ids" "private" {
  vpc_id = "${data.aws_vpc.the_vpc.id}"
  tags {
    Name = "eks_private_*"
  }
  depends_on = [
    "aws_subnet.eks_private",
  ]
}

resource "aws_route_table_association" "private_kube" {
  count = 3
  subnet_id      = "${data.aws_subnet_ids.private.ids[count.index]}"
  route_table_id = "${aws_route_table.eks_private.id}"
}

# Finally lets allow the nodes to access S3 directly 

data "aws_vpc_endpoint_service" "s3" {
  service = "s3"
}

resource "aws_vpc_endpoint" "k8s-s3" {
  vpc_id       =  "${data.aws_vpc.the_vpc.id}"
  
  service_name    = "${data.aws_vpc_endpoint_service.s3.service_name}"
  route_table_ids = ["${aws_route_table.eks_private.id}"]
}




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




# The actual EKS cluster 

resource "aws_eks_cluster" "eks_cluster" {
  name     = "${var.vpc_name}"
  role_arn = "${aws_iam_role.eks_control_plane_role.arn}"

  vpc_config {
    subnet_ids  = ["${aws_subnet.eks_private.*.id}"]
#   subnet_ids  = ["${aws_subnet.eks_private_1.id}", "${aws_subnet.eks_private_2.id}", "${aws_subnet.eks_private_3.id}"]
    security_group_ids = ["${aws_security_group.eks_control_plane_sg.id}"]
  }

  depends_on = [
    "aws_iam_role_policy_attachment.eks-policy-AmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.eks-policy-AmazonEKSServicePolicy",
  ]
}



###############################################
# Worker nodes


## Role

resource "aws_iam_role" "eks_node_role" {
  name = "eks-${var.vpc_name}-node-role"

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

resource "aws_iam_role_policy_attachment" "eks-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.eks_node_role.name}"
}

resource "aws_iam_role_policy_attachment" "eks-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "${aws_iam_role.eks_node_role.name}"
}

resource "aws_iam_role_policy_attachment" "eks-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.eks_node_role.name}"
}

resource "aws_iam_instance_profile" "eks_node_instance_profile" {
  name = "${var.vpc_name}-EKS-nodes"
  role = "${aws_iam_role.eks_node_role.name}"
}


## Worker Node Security Group
## This security group controls networking access to the Kubernetes worker nodes.


resource "aws_security_group" "eks_nodes_sg" {
  name        =  "${var.vpc_name}-nodes-sg"
  description = "Security group for all nodes in the EKS cluster [${var.vpc_name}] "
  vpc_id      = "${data.aws_vpc.the_vpc.id}"

#  ingress {
#    from_port       = 0
#    to_port         = 0
#    protocol        = "-1"
#    description     = "Allow access from withing the VPC CIDR"
#    cidr_blocks     = ["${data.aws_vpc.the_vpc.cidr_block}"]
#  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = "${
    map(
     "Name", "${var.vpc_name}-nodes-sg",
     "kubernetes.io/cluster/${var.vpc_name}", "owned",
    )
  }"
}



# Worker Node Access to EKS Master Cluster
# Now that we have a way to know where traffic from the worker nodes is coming from,
# we can allow the worker nodes networking access to the EKS master cluster.

resource "aws_security_group_rule" "https_nodes_to_plane" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.eks_control_plane_sg.id}"
  source_security_group_id = "${aws_security_group.eks_nodes_sg.id}"
  depends_on               = ["aws_security_group.eks_nodes_sg", "aws_security_group.eks_control_plane_sg" ]
}


resource "aws_security_group_rule" "communication_plane_to_nodes" {
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65534
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.eks_nodes_sg.id}"
  source_security_group_id = "${aws_security_group.eks_control_plane_sg.id}"
  depends_on               = ["aws_security_group.eks_nodes_sg", "aws_security_group.eks_control_plane_sg" ]
}

resource "aws_security_group_rule" "nodes_internode_communications" {
  type = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  description       = "allow nodes to communicate with each other"
  security_group_id = "${aws_security_group.eks_nodes_sg.id}"
  self              = true
}


# Let's allow ssh just in case
resource "aws_security_group" "ssh" {
  name        = "ssh_eks_${var.vpc_name}"
  description = "security group that only enables ssh"
  vpc_id      = "${data.aws_vpc.the_vpc.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
    #cidr_blocks = ["${data.aws_vpc.the_vpc.cidr_block}"]
  }

  tags {
    Environment  = "${var.vpc_name}"
    Organization = "Basic Service"
    Name         = "ssh_eks_${var.vpc_name}"
  }
}

## Worker Node AutoScaling Group
# Now we have everything in place to create and manage EC2 instances that will serve as our worker nodes
# in the Kubernetes cluster. This setup utilizes an EC2 AutoScaling Group (ASG) rather than manually working with
# EC2 instances. This offers flexibility to scale up and down the worker nodes on demand when used in conjunction
# with AutoScaling policies (not implemented here).

# First, let us create a data source to fetch the latest Amazon Machine Image (AMI) that Amazon provides with an
# EKS compatible Kubernetes baked in.

data "aws_ami" "eks_worker" {
  filter {
    name   = "name"
    values = ["eks-worker-*"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon Account ID
}


data "aws_region" "current" {}


# EKS currently documents this required userdata for EKS worker nodes to
# properly configure Kubernetes applications on the EC2 instance.
# We utilize a Terraform local here to simplify Base64 encoding this
# information into the AutoScaling Launch Configuration.
# More information: https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/amazon-eks-nodegroup.yaml
locals {
  eks_node_userdata = <<USERDATA
#!/bin/bash -xe

#echo http_proxy=http://cloud-proxy.internal.io:3128 >> /etc/environment
#echo https_proxy=http://cloud-proxy.internal.io:3128/ >> /etc/environment
#export http{,s}_proxy=http://cloud-proxy.internal.io
#export no_proxy=localhost,127.0.0.1,localaddress,169.254.169.254,.internal.io,logs.us-east-1.amazonaws.com
#echo "proxy=http://cloud-proxy.internal.io:3128" >> /etc/yum.conf

CA_CERTIFICATE_DIRECTORY=/etc/kubernetes/pki
CA_CERTIFICATE_FILE_PATH=$CA_CERTIFICATE_DIRECTORY/ca.crt

MODEL_DIRECTORY_PATH=~/.aws/eks
MODEL_FILE_PATH=$MODEL_DIRECTORY_PATH/eks-2017-11-01.normal.json

mkdir -p $CA_CERTIFICATE_DIRECTORY

mkdir -p $MODEL_DIRECTORY_PATH
curl -o $MODEL_FILE_PATH https://s3-us-west-2.amazonaws.com/amazon-eks/1.10.3/2018-06-05/eks-2017-11-01.normal.json
aws configure add-model --service-model file://$MODEL_FILE_PATH --service-name eks

echo "${aws_eks_cluster.eks_cluster.certificate_authority.0.data}" | base64 -d >  $CA_CERTIFICATE_FILE_PATH
INTERNAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
sed -i s,MASTER_ENDPOINT,${aws_eks_cluster.eks_cluster.endpoint},g /var/lib/kubelet/kubeconfig
sed -i s,CLUSTER_NAME,${var.vpc_name},g /var/lib/kubelet/kubeconfig
sed -i s,REGION,${data.aws_region.current.name},g /etc/systemd/system/kubelet.service
sed -i s,MAX_PODS,20,g /etc/systemd/system/kubelet.service
sed -i s,MASTER_ENDPOINT,${aws_eks_cluster.eks_cluster.endpoint},g /etc/systemd/system/kubelet.service
sed -i s,INTERNAL_IP,$INTERNAL_IP,g /etc/systemd/system/kubelet.service
DNS_CLUSTER_IP=10.100.0.10
if [[ $INTERNAL_IP == 10.* ]] ; then DNS_CLUSTER_IP=172.20.0.10; fi
sed -i s,DNS_CLUSTER_IP,$DNS_CLUSTER_IP,g /etc/systemd/system/kubelet.service
sed -i s,CERTIFICATE_AUTHORITY_FILE,$CA_CERTIFICATE_FILE_PATH,g /var/lib/kubelet/kubeconfig
sed -i s,CLIENT_CA_FILE,$CA_CERTIFICATE_FILE_PATH,g  /etc/systemd/system/kubelet.service
systemctl daemon-reload
systemctl restart kubelet
cat > /home/ec2-user/.ssh/authorized_keys <<EFO
ssh-dss AAAAB3NzaC1kc3MAAACBAPfnMD7+UvFnOaQF00Xn636M1IiGKb7XkxJlQfq7lgyzWroUMwXFKODlbizgtoLmYToy0I4fUdiT4x22XrHDY+scco+3aDq+Nug+jaKqCkq+7Ms3owtProd0Jj6AWCFW+PPs0tGJiObieci4YqQavB299yFNn+jusIrDsqlrUf7xAAAAFQCi4wno2jigjedM/hFoEFiBR/wdlwAAAIBl6vTMb2yDtipuDflqZdA5f6rtlx4p+Dmclw8jz9iHWmjyE4KvADGDTy34lhle5r3UIou5o3TzxVtfy00Rvyd2aa4QscFiX5jZHQYnbIwwlQzguCiF/gtYNCIZit2B+R1p2XTR8URY7CWOTex4X4Lc88UEsM6AgXIpJ5KKn1pK2gAAAIAJD8p4AeJtnimJTKBdahjcRdDDedD3qTf8lr3g81K2uxxsLOudweYSZ1oFwP7RnZQK+vVE8uHhpkmfsy1wKCHrz/vLFAQfI47JDX33yZmBLtHjjfmYDdKVn36XKZ5XrO66vcbX2Jav9Hlqb6w/nekBx2nbJaZnHwlAp70RU13gyQ== renukarya@Renukas-MacBook-Pro.local
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC2d7DncA3QdZoxXzkIaU4xcPZ0IJ97roh4qF3gE1dse3H/aQ5V3lYZ9HuhVYm1UnMvNvKXIdvsHUPEmwe6s9X8Fj1fxpxuF+/C6d5+5raHffEAqU/YEFa0V8vxcSCedQoiDfJwzUA7NTcMBEFAH4MdTa4hmGnlwEeW4JWFiBmr2y5UVRfrZhM+DVdv5hxFQCyTjMXz4ZOmfMnvC6W/ZNzCersDES36Mo/nqHQWIH6Xd5BfOYWrs2zW/MZRUy4Yt9hFyuKizSt77SpjmBYGeagHS0TSti36nAduMbr3dkbvPF3JhbsXxlGpZgaYR51zjK5cQNEEj2hCExWD2pWUKOzD jeff@wireles-guest-16-34-212.uchicago.edu
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCw48loSG10QUtackRFsmxYXd3OezarZLuT7F+bxKYsj9rx2WEehDxg1xWESMSoHxGlHMSWpt0NMnBC2oqRz19wk3YjE/LoOaDXZmzc6UBVZo4dgItKV2+T9RaeAMkCgRcp4EsN2Rw+GNoT2whIH8jrAi2HhoNSau4Gi4zyQ2px7xBtKdco5qjQ1a6s1EMqFuOL0jqqmAqMHg4g+oZnPl9uRzZao4UKgao3ypdTP/hGVTZc4MXGOskHpyKuvorFqr/QUg0suEy6jN3Sj+qZ+ETLXFfDDKjjZsrVdR4GNcQ/sMtvhaMYudObNgNHU9yjVL5vmRBCNM06upj3RHtVx0/L rpowell@rpowell.local
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDJTr2yJtsOCsQpuKmqXmzC2itsUC1NAybH9IA3qga2Cx96+hMRLRs16vWTTJnf781UPC6vN1NkCJd/EVWD87D3AbxTF4aOKe3vh5fpsLnVI67ZYKsRl8VfOrIjB1KuNgBD1PrsDeSSjO+/sRCrIuxqNSdASBs5XmR6ZNwowF0tpFpVNmARrucCjSKqSec8VY2QneX6euXFKM2KJDsp0m+/xZqLVa/iUvBVplW+BGyPe+/ETlbEXe5VYlSukpl870wOJOX64kaHvfCaFe/XWH9uO+ScP0J/iWZpMefWyxCEzvPaDPruN+Ed7dMnePcvVB8gdX0Vf0pHyAzulnV0FNLL ssullivan@HPTemp
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDkJRaRKEl9mqTm1ZSWqO9KX3b/zl0cv6RUshS4eST42LkiLjcrH2atsh6IWnvPyy6cdG7c45ntdEEWJ9yXxMhuCKGbFyz6QIgb4h9ZDJqFtTq7w2IhqfsApXBUm6XmZJGQxzB/t96UQIP1rdV9zhkx1OT+2hIrKFiDiCY5H5skirepFjyQxfmThGl2s45ay4PDwL6Spmx3pdgJTVUijcgTff8ZAnARpDJTeVWc/oGZtRG68+/iaVisGnDEVrt2YaQek0p8bTVSuiLGoZ/RC0luoBSdBvrPgU+UKOQXpqTwdZWOug6v/yInwROAKUvElD6AOoJbXLnbhzG78llD47CP kyle@Kyles-MacBook-Pro.local
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDYe74TEoKYZm9cfCTAsjICaKUzAkh3/Y6mhzhhzYIqra0J5efQ+SJcDt7soOJ2qE1zOcGGvuA8belebkjOZDv50Mn5cEvaKsbpS9Poq0H02TzKby42pfV4TER1XbByuHC9eltsbn7efnmsdzcaY4uv2bMVXVauO0/XwHgoatVAeKvc+Gwkgx5BqiSI/MY+qDpldufL6f0hzsxFVlC/auJp+NWmKDjfCaS+mTBEezkXlg04ARjn3Pl68troK2uP2qXNESFgkBDTsLftM6p8cKIGjVLZI2+D4ayjbRbKWNQxS3L5CEeobzrovtls5bPSbsG/MxFdZC6EIbJH5h/6eYYj
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC6vuAdqy0pOwC5rduYmnjHTUsk/ryt//aJXwdhsFbuEFxKyuHsZ2O9r4wqwqsVpHdQBh3mLPXNGo2MZFESNEoL1olzW3VxXXzpujGHDd/F9FmOpnAAFz90gh/TM3bnWLLVWF2j7SKw68jUgijc28SnKRNRXpKJLv6PN9qq8OMHaojnEzrsGMb69lMT8dro1Yk71c4z5FDDVckN9UVL7W03+PE/dN6AtNWMlIEWlgm6/UA9Og+w9VYQnhEylxMpmxdO0SAbkIrr3EPC16kRewfovQLZJsw2KRo4EK62Xyjem/M1nHuJo4KpldZCOupxfo6jZosO/5wpKF1j8rF6vPLkHFYNwR62zTrHZ58NVjYTRF927kW7KHEq0xDKSr5nj9a8zwDInM/DkMpNyme4Jm3e4DOSQ3mP+LYG9TywNmf9/rVjEVwBBxqGRi27ex6GWcLm4XB58Ud3fhf5O5BDdkLYD1eqlJE5M4UG5vP5C9450XxW5eHUi/QK2/eV+7RijrEtczlkakPVO7JdWDZ44tX9sjkAlLSvgxkn4xZSdfqm/aJBIHUpoEitkZf9kgioZdDz2xmBDScG3c3g5UfPDrMvSTyoMliPo7bTIjdT/R1XV27V8ByrewwK/IkS70UkbIpE3GNYBUIWJBdNPpgjQ5scMOvhEIjts2z4KKq1mUSzdQ== zac
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDOHPLoBC42tbr7YiQHGRWDOZ+5ItJVhgSqAOOb8bHD65ajen1haM2PUvqCrZ0p7NOrDPFRBlNIRlhC2y3VdnKkNYSYMvHUEwt8+V3supJBj2Tu8ldzpQthDu345/Ge4hqwp+ujZVRfjjAFaFLkMtqvlAXkj7a2Ip6ZZEhd8NcRq/mQET3eCaBR5/+BGzEMBVQGTSGYOY5rOkR8PNQiX+BF7qIX/xRHo8GCOztO4KmDLmaZV63ovQwr01PXSGEq/VGfHwXAvzX13IXTYE2gechEyudhRGZBbhayyaKD7VRoKzd4BZuuUrLCSpMDWBK/qtECcP4pCXW/0Wi2OCzUen3syh/YrOtJD1CUO+VvW6/8xFrcBeoygFW87hW08ncXLT/XxpgWeExJrTGIxjr4YzcsWPBzxI7/4SmKbaDSjx/RMX7x5WbPc5AZzHY17cKcpdc14weG+sm2OoKF5RqnFB/JpBaNxG+Zq8qYC/6h8fOzDWo5+qWKO/UlWaa3ob2QpG8qOBskoyKVG3ortQ04E04DmoaOiSsXoj0U0zaJnxpdF+a0i31RxQnjckTMEHH8Y2Ow8KIG45tzhJx9NbqSj9abk3yTzGA7MHvugQFpuTQ3gaorfG+A9RGUmx6aQNwXUGu+DWRF7lFeaPJt4CDjzbDUGP/b5KJkWK0DDAI61JfOew== fauzi@uchicago.edu
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCfX+T2c3+iBP17DS0oPj93rcQH7OgTCKdjYS0f9s8sIKjErKCao0tRNy5wjBhAWqmq6xFGJeA7nt3UBJVuaGFbszIzs+yvjZYYVrJQdfl0yPbrKRMd/Ch77Jnqbu97Uyu8UxhGkzqEcxQrdBqhqkakhQULjcjZBnk0M1PrLwW+Pl1kRCnXnX/x3YzDR/Ltgjc57qjPbqz7+CBbuFo5OCYOY94pcXetHskvx1AAQ7ZT2c/F/p6vIH5jPKnCTjuqWuGoimp/alczLMO6n+aHgzqc9NKQUScxA0fCGxFeoEdd6b370E7j8xXMIA/xSmq8lFPam+fm3117nC4m29sRktoBI8YP4L7VPSkM/hLp/vRzVJf6U183GfvUSZPERrg+NvMeah9vgkTgzH0iN1+s2xPj6eFz7VUOQtLYTchMZ/qyyGhUzJznY0szocVd6iDbMAYm67R+QtgYEBD1hYrtUD052imb62nEXHFSL3V6369GaJ+k5BIUTGweOaUxGbJlb6fG2Aho4EWaigYRMtmlKgDFaCeJGjlQrFR9lKFzDBc3Af3RefPDVsavYGdQQRUAmueGjlks99Bvh2U53HQgQvc0iQg3ijey2YXBr6xFCMeG7MJZbPcrlQLXko4KygK94EcDPZnIH542CrtAySk/UxxwZv5u0dLsh7o+ZK9G6PO1+Q== reubenonrye@uchicago.edu
EFO

sudo cat /home/ec2-user/.ssh/authorized_keys > /root/.ssh/authorized_keys
USERDATA
}

resource "aws_launch_configuration" "eks_launch_configuration" {
  associate_public_ip_address = false
  iam_instance_profile        = "${aws_iam_instance_profile.eks_node_instance_profile.name}"
  image_id                    = "${data.aws_ami.eks_worker.id}"
  instance_type               = "${var.instance_type}"
  name_prefix                 = "eks-${var.vpc_name}"
  security_groups             = ["${aws_security_group.eks_nodes_sg.id}", "${aws_security_group.ssh.id}"]
  user_data_base64            = "${base64encode(local.eks_node_userdata)}"
  key_name                    = "${var.ec2_keyname}"

  lifecycle {
    create_before_destroy = true
    ignore_changes  = ["user_data_base64"]
  }
}


# Finally, we create an AutoScaling Group that actually launches EC2 instances based on the
# AutoScaling Launch Configuration.

# NOTE: The usage of the specific kubernetes.io/cluster/* resource tag below is required for EKS
# and Kubernetes to discover and manage compute resources.

resource "aws_autoscaling_group" "eks_autoscaling_group" {
  desired_capacity     = 2
  launch_configuration = "${aws_launch_configuration.eks_launch_configuration.id}"
  max_size             = 5
  min_size             = 2
  name                 = "eks-worker-node-${var.vpc_name}"
  vpc_zone_identifier  = ["${aws_subnet.eks_private.*.id}"]


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
}

# NOTE: At this point, your Kubernetes cluster will have running masters and worker nodes, however, the worker nodes will
# not be able to join the Kubernetes cluster quite yet. The next section has the required Kubernetes configuration to
# enable the worker nodes to join the cluster.

# Required Kubernetes Configuration to Join Worker Nodes
# The EKS service does not provide a cluster-level API parameter or resource to automatically configure the underlying
# Kubernetes cluster to allow worker nodes to join the cluster via AWS IAM role authentication.

# To output an IAM Role authentication ConfigMap from your Terraform configuration:

locals {
  config-map-aws-auth = <<CONFIGMAPAWSAUTH
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
CONFIGMAPAWSAUTH
}

